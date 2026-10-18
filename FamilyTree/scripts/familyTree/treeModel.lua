-- Engine-independent occurrence tree. The same person can appear on separate
-- lineage paths; IDs already on the current path are omitted before allocation.
local Model = {}
Model.__index = Model
Model.maxNodes, Model.maxCache, Model.maxPending = 256, 64, 4
Model.cardWidth, Model.cardHeight, Model.gap, Model.step = 280, 180, 36, 240

function Model.new(root, send, changed)
    local self = setmetatable({send=send, changed=changed, active=true, nodes={}, count=0,
        pending=0, cache={}, cacheKeys={}, nextKey=0, revision=0}, Model)
    self.root = self:add(root)
    return self
end
function Model:add(row, parent, direction)
    self.nextKey = self.nextKey + 1
    local node = {key=self.nextKey, row=row, parent=parent, direction=direction, branches={}}
    self.nodes[node.key]=node;self.count=self.count+1
    return node
end
function Model:canExpand(node, direction)
    return node.row.id and node.row.status~="unknown" and
        (direction=="children" or direction=="parents")
end
local function onPath(node,id)
    if not id then return false end
    while node do
        if node.row.id==id then return true end
        node=node.parent
    end
    return false
end
function Model:branch(node, direction)
    local branch=node.branches[direction]
    if not branch then
        branch={children={}, open=false, nextPage=0, seen={}}
        node.branches[direction]=branch
    end
    return branch
end
function Model:remember(key, data)
    if not self.cache[key] then
        self.cacheKeys[#self.cacheKeys+1]=key
        if #self.cacheKeys>self.maxCache then self.cache[table.remove(self.cacheKeys,1)]=nil end
    end
    self.cache[key]=data
end
function Model:load(node, direction)
    local branch=self:branch(node,direction)
    if not self.active or branch.pending or branch.nextPage==nil then return end
    if self.pending>=self.maxPending then branch.error="Please wait for the other branches.";self.changed();return end
    local page=branch.nextPage
    local key=node.row.id..":"..direction..":"..page
    local revision=self.revision
    local function apply(data)
        if not self.active or revision~=self.revision then return end
        branch.pending=false;branch.error=nil
        if not data or data.error then branch.error=data and data.error or "No response. Try again.";self.changed();return end
        local rows,seen={},{}
        for _,row in ipairs(data.rows) do
            -- Filter per occurrence, not in the shared response cache: a person
            -- can be a return link here but a valid relative on another path.
            -- Omitted links consume neither card space nor the view budget.
            if not row.id or not (branch.seen[row.id] or seen[row.id] or onPath(node,row.id)) then
                rows[#rows+1]=row
                if row.id then seen[row.id]=true end
            end
        end
        if self.count+#rows>self.maxNodes then
            branch.error="View limit reached. Focus a person or Collapse all."
            self.changed();return
        end
        for _,row in ipairs(rows) do
            branch.children[#branch.children+1]=self:add(row,node,direction)
            if row.id then branch.seen[row.id]=true end
        end
        branch.nextPage=data.nextPage;branch.loaded=true
        self.changed()
    end
    if self.cache[key] then apply(self.cache[key]);return end
    branch.pending=true;branch.error=nil;self.pending=self.pending+1
    self.changed()
    self.send({action="branch",id=node.row.id,relation=direction,page=page},function(data)
        if not self.active or revision~=self.revision then return end
        self.pending=self.pending-1
        if data and not data.error then self:remember(key,data) end
        apply(data)
    end)
end
function Model:toggle(node, direction)
    if not self:canExpand(node,direction) then return end
    local branch=self:branch(node,direction)
    branch.open=not branch.open
    if branch.open and not branch.loaded and not branch.pending then self:load(node,direction)
    else self.changed() end
end
function Model:seedFamily(data)
    -- A bounded household snapshot is the initial state of this same tree,
    -- not a second renderer. Seed raw cache pages so collapse/reopen stays local.
    local function seed(node,direction,rows,nextPage)
        self:remember(node.row.id..":"..direction..":0",{rows=rows,nextPage=nextPage})
        self:toggle(node,direction)
    end
    seed(self.root,"parents",data.parents or {})
    seed(self.root,"children",data.children or {},data.nextPage)
    local seen={[self.root.row.id]=true}
    for _,node in ipairs(self.root.branches.parents.children) do if node.row.id then seen[node.row.id]=true end end
    for _,child in ipairs(self.root.branches.children.children) do
        local other=child.row.coParent
        if other and other.id and not seen[other.id] then
            seen[other.id]=true
            local parent={}
            for k,v in pairs(self.root.row) do parent[k]=v end
            parent.relationship=child.row.parentRole
            seed(child,"parents",{parent,other})
        end
    end
end
function Model:collapseAll()
    -- Drop occurrence state but retain the bounded response cache. In-flight
    -- replies belong to the previous revision and cannot repopulate this view.
    local row=self.root.row
    self.revision=self.revision+1;self.nodes={};self.count=0;self.pending=0
    self.root=self:add(row);self.changed()
end
function Model:close() self.active=false end

function Model:layout()
    local nodes,edges={self.root},{}
    self.root.x,self.root.y=0,0
    local function children(node,direction)
        local b=node.branches[direction]
        local list={}
        for _,child in ipairs(b and b.open and b.children or {}) do list[#list+1]=child end
        if direction=="children" then
            -- Keep siblings of the same known parent pair together across pages.
            -- Unknown co-parents must not imply that unrelated children are siblings.
            table.sort(list,function(a,b)
                local ak=a.row.coParentID or ("~"..a.key)
                local bk=b.row.coParentID or ("~"..b.key)
                return ak==bk and a.key<b.key or ak<bk
            end)
        end
        return list
    end
    local widths={}
    local function measure(node,direction)
        local width=0
        for _,child in ipairs(children(node,direction)) do width=width+measure(child,direction) end
        widths[node.key]=math.max(self.cardWidth+self.gap,width)
        return widths[node.key]
    end
    local function place(node,direction)
        local list=children(node,direction)
        local width=0;for _,child in ipairs(list) do width=width+widths[child.key] end
        local left=node.x-width/2
        for _,child in ipairs(list) do
            child.x=left+widths[child.key]/2;left=left+widths[child.key]
            child.y=node.y+self.step*(direction=="parents" and -1 or 1)
            nodes[#nodes+1]=child;edges[#edges+1]={from=node,to=child}
            place(child,direction)
        end
    end
    for _,direction in ipairs({"parents","children"}) do
        measure(self.root,direction);place(self.root,direction)
    end
    -- Pack reversed subtrees into the nearest free space on their generations,
    -- instead of pushing every maternal/collateral branch outside the whole tree.
    -- Forbidden shift intervals are derived only from cards on the same row.
    local function pack(first)
        local intervals={}
        for a=first,#nodes do
            for b=1,first-1 do
                if nodes[a].y==nodes[b].y then
                    local delta=nodes[b].x-nodes[a].x
                    local margin=self.cardWidth+self.gap
                    intervals[#intervals+1]={delta-margin,delta+margin}
                end
            end
        end
        table.sort(intervals,function(a,b)return a[1]<b[1]end)
        local right=0
        for _,v in ipairs(intervals) do if right>v[1] and right<v[2] then right=v[2] end end
        local left=0
        for j=#intervals,1,-1 do local v=intervals[j];if left>v[1] and left<v[2] then left=v[1] end end
        local shift=math.abs(left)<right and left or right
        for j=first,#nodes do nodes[j].x=nodes[j].x+shift end
    end
    local i=1
    while i<=#nodes do
        local node=nodes[i]
        if node.direction then
            local direction=node.direction=="parents" and "children" or "parents"
            local list=children(node,direction)
            for _,child in ipairs(list) do measure(child,direction) end
            if #list>0 then
                local first=#nodes+1
                place(node,direction)
                pack(first)
            end
        end
        i=i+1
    end
    -- Route unrelated edges on separate tracks. Disjoint horizontal spans may
    -- reuse a track, but overlapping spans never become a false shared family bus.
    local bands,ports={},{}
    local minGen,maxGen=0,0
    for _,node in ipairs(nodes) do
        node.generation=math.floor(node.y/self.step+0.5)
        minGen=math.min(minGen,node.generation);maxGen=math.max(maxGen,node.generation)
    end
    -- A visible co-parent also connects to their other known children, even
    -- when those children's Parents controls have not been opened. Reuse only
    -- already visible, same-generation occurrences; do not load or invent nodes.
    for _,child in ipairs(nodes) do
        if child.direction=="children" and child.row.coParentID then
            local candidate,connected
            for _,edge in ipairs(edges) do
                local other=edge.from==child and edge.to or (edge.to==child and edge.from)
                if other and other.row.id==child.row.coParentID then connected=true;break end
            end
            if not connected then
                for _,parent in ipairs(nodes) do
                    if parent.row.id==child.row.coParentID and parent.generation==child.generation-1 and
                        (not candidate or math.abs(parent.x-child.x)<math.abs(candidate.x-child.x)) then candidate=parent end
                end
                if candidate then edges[#edges+1]={from=candidate,to=child,roleOverride=child.row.coParentRole} end
            end
        end
    end
    local function port(node,side,edge)
        local key=node.key..side
        ports[key]=ports[key] or {}
        ports[key][#ports[key]+1]={node=node,edge=edge,side=side}
    end
    for _,edge in ipairs(edges) do
        local a,b=edge.from,edge.to
        edge.upper=a.generation<b.generation and a or b
        edge.lower=edge.upper==a and b or a
        edge.role=edge.roleOverride or (b.direction=="parents" and b.row.relationship or b.row.parentRole)
        port(edge.upper,"topPort",edge);port(edge.lower,"bottomPort",edge)
    end
    for _,list in pairs(ports) do
        table.sort(list,function(a,b)
            local function other(v)return v.edge.upper==v.node and v.edge.lower or v.edge.upper end
            return other(a).x==other(b).x and other(a).key<other(b).key or other(a).x<other(b).x
        end)
        for j,v in ipairs(list) do
            v.edge[v.side]=v.node.x+(j/(#list+1)-0.5)*(self.cardWidth-24)
        end
    end
    for _,edge in ipairs(edges) do
        local gen=edge.upper.generation
        bands[gen]=bands[gen] or {tracks={}}
        local tracks=bands[gen].tracks
        local lo,hi=math.min(edge.topPort,edge.bottomPort)-8,math.max(edge.topPort,edge.bottomPort)+8
        local lane=1
        while tracks[lane] do
            local collision=false
            for _,span in ipairs(tracks[lane]) do if lo<span[2] and hi>span[1] then collision=true;break end end
            if not collision then break end
            lane=lane+1
        end
        tracks[lane]=tracks[lane] or {};tracks[lane][#tracks[lane]+1]={lo,hi}
        edge.lane=lane
    end
    local heights={[0]=0}
    local function spacing(gen)return self.cardHeight+40+10*#bands[gen].tracks end
    for gen=0,maxGen-1 do heights[gen+1]=heights[gen]+spacing(gen) end
    for gen=-1,minGen,-1 do heights[gen]=heights[gen+1]-spacing(gen) end
    for _,node in ipairs(nodes) do node.y=heights[node.generation] end
    for _,edge in ipairs(edges) do edge.trackY=edge.upper.y+self.cardHeight/2+20+10*(edge.lane-1) end
    local bounds={left=-self.cardWidth/2,right=self.cardWidth/2,top=-self.cardHeight/2,bottom=self.cardHeight/2}
    for _,node in ipairs(nodes) do
        bounds.left=math.min(bounds.left,node.x-self.cardWidth/2);bounds.right=math.max(bounds.right,node.x+self.cardWidth/2)
        bounds.top=math.min(bounds.top,node.y-self.cardHeight/2);bounds.bottom=math.max(bounds.bottom,node.y+self.cardHeight/2)
    end
    return nodes,edges,bounds
end
return Model
