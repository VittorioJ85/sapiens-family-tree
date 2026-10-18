-- A clipped, pannable viewport using native Sapiens views. This module stays
-- outside mainThread/ui so Hammerstone does not try to patch a nonexistent file.
local mjm=mjrequire "common/mjm"
local buttons=mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local common=mjrequire "mainThread/ui/uiCommon/uiCommon"
local objectViews=mjrequire "mainThread/ui/uiCommon/uiGameObjectView"
local players=mjrequire "mainThread/playerSapiens"
local logic=mjrequire "mainThread/logicInterface"
local timer=mjrequire "common/timer"
local Model=mjrequire "familyTree/treeModel"
local Tree={}
Tree.__index=Tree
local gold=mjm.vec4(0.72,0.59,0.34,1)
local maternal=mjm.vec4(0.87,0.60,0.79,1)
local paternal=mjm.vec4(0.42,0.76,0.92,1)
local function position(view,x,y,z)
    view.relativePosition=ViewPosition(MJPositionInnerLeft,MJPositionTop)
    view.baseOffset=mjm.vec3(x,-y,z or 1)
end
local function text(parent,value,x,y,size,color)
    local v=TextView.new(parent);position(v,x,y,3)
    v.font=Font(common.fontName,size);v.color=color or mj.textColor;v.text=value
    v.masksEvents=false
    return v
end
local function fill(parent,x,y,w,h,color,z)
    local v=ColorView.new(parent);position(v,x,y,z)
    v.size=mjm.vec2(w,h);v.color=color;v.masksEvents=false
    return v
end
local function button(parent,label,x,y,width,fn,disabled,scale)
    scale=scale or 1
    local v=buttons:create(parent,mjm.vec2(width*scale,26*scale),buttons.types.standard_10x3)
    position(v,x,y,4);buttons:setText(v,"")
    buttons:setClickFunction(v,fn);buttons:setDisabled(v,disabled or false)
    -- Native button fonts are fixed-size. A separate event-transparent label
    -- scales with the card while retaining native focus/click behavior.
    local labelView=text(v,label,7*scale,5*scale,14*scale,disabled and mj.disabledTextColor or mj.textColor)
    return v,labelView
end
function Tree.open(parent,root,options)
    local self=setmetatable({parent=parent,options=options,active=true,timers={},scale=0.9,panX=0,panY=0},Tree)
    parent:removeAllSubviews()
    button(parent,"Archive",20,75,105,options.archive)
    button(parent,"Starting Sapien",135,75,150,options.home)
    button(parent,"Back",295,75,80,options.back,not options.hasHistory)
    button(parent,"Center",385,75,85,function()self:center()end)
    button(parent,"Collapse all",480,75,120,function()self.model:collapseAll();self:center()end)
    button(parent,"Refresh",610,75,95,options.refresh)
    button(parent,"Fit",715,75,55,function()self:fit()end)
    button(parent,"Names",780,75,75,options.names)
    button(parent,"-",parent.size.x-190,75,35,function()self:zoom(self.scale-0.1)end)
    self.zoomLabel=text(parent,"90%",parent.size.x-145,81,14)
    button(parent,"+",parent.size.x-85,75,35,function()self:zoom(self.scale+0.1)end)
    self.title=text(parent,"Family of "..options.short(root.name,40),25,113,22,gold)
    self.oldestButton,self.oldestLabel=button(parent,"Oldest: counting...",parent.size.x-300,112,275,function()
        if self.oldest then options.focus(self.oldest) end
    end,true)
    self.summaryText=text(parent,"",25,143,14)
    self.viewport=View.new(parent);position(self.viewport,20,170,1)
    self.viewport.size=mjm.vec2(parent.size.x-40,parent.size.y-220)
    self.viewport:setClipChildren(true)
    fill(self.viewport,0,0,self.viewport.size.x,self.viewport.size.y,mjm.vec4(0.06,0.07,0.075,0.8),-1)
    self.content=View.new(self.viewport);position(self.content,0,0,1)
    self.content.size=self.viewport.size;self.content.masksEvents=false
    self.notice=text(parent,"Drag empty space to pan. Scroll or +/- to zoom. Select a name to focus; magnifier to visit.",25,parent.size.y-38,14)
    self.notice.wrapWidth=parent.size.x-50
    self.viewport.mouseDown=function(index,loc)
        if index==0 then self.drag={x=loc.x,y=loc.y,panX=self.panX,panY=self.panY} end
    end
    self.viewport.mouseDragged=function(loc)
        if self.active and self.drag then
            self.panX=self.drag.panX+loc.x-self.drag.x
            self.panY=self.drag.panY-loc.y+self.drag.y
            self:move()
        end
    end
    self.viewport.mouseUp=function()self.drag=nil end
    self.viewport.mouseWheel=function(loc,delta)
        if delta.y~=0 then self:zoom(self.scale+(delta.y>0 and 0.1 or -0.1),loc) end
    end
    self.starting=true
    self.model=Model.new(root,function(request,callback)self:send(request,callback)end,function()
        if not self.starting then self:render() end
    end)
    if options.family then self.model:seedFamily(options.family) end
    self.starting=false
    self:setSummary(options.summary,options.oldestID)
    if options.family then self:fit() end
    return self
end
function Tree:send(request,callback)
    local done=false
    local timeout
    local function complete(data)
        if done then return end
        done=true
        if timeout then timer:removeTimer(timeout);self.timers[timeout]=nil end
        if self.active then callback(data) end
    end
    timeout=timer:addCallbackTimer(10,function()complete({error="No server response. Retry this branch."})end)
    self.timers[timeout]=true
    logic:callServerFunction("familyTreeRequest",request,complete)
end
function Tree:close()
    self.active=false;self.drag=nil
    if self.model then self.model:close() end
    for id in pairs(self.timers) do timer:removeTimer(id) end
    self.timers={}
    self.content:removeAllSubviews()
    self.cards,self.lines,self.guides={},{},{}
end
function Tree:setSummary(summary,oldestID)
    self.oldestID=oldestID
    self.oldest=summary and not summary.error and not summary.unresolved and summary.oldest or nil
    buttons:setDisabled(self.oldestButton,not self.oldest)
    self.oldestLabel.text=self.oldest and ("Oldest: "..self.options.short(self.oldest.name,26)) or
        (summary and "Oldest: unavailable" or "Oldest: counting...")
    self.oldestLabel.color=self.oldest and mj.textColor or mj.disabledTextColor
    if summary and not summary.error and not summary.unresolved then
        self.summaryText.text=string.format("Family: %d recorded | %d living | %d deceased | %d absent / unconfirmed | * Oldest living member",
            summary.living+summary.deceased+summary.unknown,summary.living,summary.deceased,summary.unknown)
    else self.summaryText.text=summary and "Family membership unavailable" or "Family members: counting..." end
    if self.model then self:render() end
end
function Tree:center() self.panX,self.panY=0,0;self:move() end
function Tree:fit()
    local b=self.bounds
    if not b then return end
    self.scale=math.max(0.2,math.min(1.0,(self.viewport.size.x-60)/(b.right-b.left),
        (self.viewport.size.y-60)/(b.bottom-b.top)))
    self.panX=-(b.left+b.right)*self.scale/2;self.panY=-(b.top+b.bottom)*self.scale/2
    self.zoomLabel.text=math.floor(self.scale*100+0.5).."%";self:render()
end
function Tree:zoom(scale,loc)
    if not self.active then return end
    scale=math.max(0.2,math.min(1.3,scale))
    local x=loc and loc.x-self.viewport.size.x/2 or 0
    local y=loc and self.viewport.size.y/2-loc.y or 0
    self.panX=x-(x-self.panX)*scale/self.scale
    self.panY=y-(y-self.panY)*scale/self.scale
    self.scale=scale;self.zoomLabel.text=math.floor(scale*100+0.5).."%"
    self:render()
end
function Tree:card(node)
    local scale=self.scale
    local view=View.new(self.content);view.size=mjm.vec2(Model.cardWidth*scale,Model.cardHeight*scale)
    view.masksEvents=false
    local row=node.row
    local border=(node==self.model.root or node.key==self.traceKey) and gold or mjm.vec4(0.36,0.39,0.39,1)
    fill(view,0,0,view.size.x,view.size.y,border)
    fill(view,2,2,view.size.x-4,view.size.y-4,mjm.vec4(0.12,0.14,0.15,1),2)
    local name=(row.id==self.oldestID and "* " or "")..(row.name or "Unknown")
    local available=row.id and row.status~="unknown"
    button(view,self.options.short(name,23),7*scale,6*scale,175,function()self.options.focus(row)end,not available,scale)
    button(view,self.traceKey==node.key and "All" or "Trace",188*scale,6*scale,50,function()
        if self.traceKey==node.key then self.traceKey=nil else self.traceKey=node.key end
        self:render()
    end,false,scale)
    local live=available and row.status~="deceased" and players:getInfo(row.id)
    local zoom=button(view,"",244*scale,6*scale,28,function()self.options.visit(row)end,not live,scale)
    buttons:setIconModel(zoom,"icon_inspect")
    local status
    if row.status=="deceased" then status="Deceased | age "..tostring(row.ageAtDeath or "?")
    elseif row.status=="unknown" then status="No recorded information"
    elseif row.age then status="Alive | age "..tostring(row.age)
    elseif row.status=="removed" then status="Absent / unconfirmed"
    else status="Last recorded alive | age unknown" end
    local relationship=node==self.model.root and "Focus person" or
        ((row.relationship or "Relative").." of "..(node.parent.row.name or "Unknown"))
    -- Reserve a separate clipped text column so long names/dates cannot cover
    -- the native portrait. All geometry scales with the existing card.
    local details=View.new(view);position(details,8*scale,37*scale,3)
    details.size=mjm.vec2(190*scale,80*scale);details.masksEvents=false
    details:setClipChildren(true)
    text(details,self.options.short(relationship,43),0,0,12*scale)
    local other=row.coParentRole and (row.coParentRole..": "..(row.coParentName or "Unknown")) or
        (node.direction=="parents" and "Parent branch" or "")
    text(details,self.options.short(other,43),0,16*scale,12*scale,
        row.coParentRole=="Mother" and maternal or paternal)
    text(details,status,0,32*scale,12*scale)
    text(details,"Born: "..(row.birthDate or "Unknown"),0,48*scale,12*scale)
    local last=row.status=="deceased" and ("Died: "..(row.deathDate or "Unknown")) or
        (not row.birthDate and row.childDate and ("Child since: "..row.childDate) or "")
    text(details,last,0,64*scale,12*scale)
    -- Use only the client's current follower data, never fetch hidden objects
    -- or invent an appearance for archived people without visual records.
    if live and live.sharedState and live.objectTypeIndex then
        local portrait=objectViews:create(view,mjm.vec2(64*scale,64*scale),objectViews.types.backgroundCircle)
        position(portrait,206*scale,49*scale,3);portrait.masksEvents=false
        objectViews:setObject(portrait,live,nil,nil)
    else
        text(view,"No portrait",207*scale,76*scale,10*scale,mj.disabledTextColor)
    end
    for i,direction in ipairs({"parents","children"}) do
        local branch=self.model:branch(node,direction)
        local label=(branch.open and "- " or "+ ")..(direction=="parents" and "Parents" or "Children")
        local x=i==1 and 8 or 144
        button(view,label,x*scale,121*scale,128,function()self.model:toggle(node,direction)end,
            not self.model:canExpand(node,direction),scale)
        if branch.open then
            if branch.pending then text(view,"Loading...",x*scale,153*scale,12*scale)
            elseif branch.error or (branch.loaded and branch.nextPage~=nil) then
                local retry=branch.error~=nil
                button(view,retry and "Retry" or "More",x*scale,149*scale,128,function()self.model:load(node,direction)end,false,scale)
            elseif branch.loaded and #branch.children==0 then text(view,"No new people",x*scale,153*scale,11*scale) end
        end
    end
    return view
end
function Tree:render()
    if not self.active then return end
    self.nodes,self.edges,self.bounds=self.model:layout()
    self.content:removeAllSubviews();self.cards={};self.lines={};self.guides={}
    local traced
    for _,node in ipairs(self.nodes) do if node.key==self.traceKey then traced=node end end
    if not traced then self.traceKey=nil end
    local message=traced and ("Connections of "..(traced.row.name or "Unknown").." only. Click All to restore all lines.") or
        "Pink: mother. Blue: father. Gold: unspecified. Trace isolates a person's links. Drag to pan; Fit for an overview."
    for _,node in ipairs(self.nodes) do
        for _,branch in pairs(node.branches) do
            if branch.open and branch.error then message=branch.error end
        end
    end
    self.notice.text=message
    local generations={}
    for _,node in ipairs(self.nodes) do
        if not generations[node.generation] then
            generations[node.generation]=true
            local label=node.generation==0 and "Focus generation" or ("Generation "..string.format("%+d",node.generation))
            self.guides[#self.guides+1]={y=node.y-Model.cardHeight/2-18,
                view=text(self.content,label,0,0,12*self.scale,mjm.vec4(0.55,0.60,0.62,1))}
        end
    end
    -- Only visible cards create buttons. Lines are cheap clipped native quads.
    for i=1,#self.edges*6 do self.lines[i]=fill(self.content,0,0,1,1,gold,0) end
    self:move()
end
function Tree:move()
    if not self.active or not self.bounds then return end
    local size,scale=self.viewport.size,self.scale
    -- Keep at least a portion of the explored tree reachable at the edges.
    self.panX=math.max(-size.x/2-self.bounds.right*scale+60,math.min(size.x/2-self.bounds.left*scale-60,self.panX))
    self.panY=math.max(-size.y/2-self.bounds.bottom*scale+40,math.min(size.y/2-self.bounds.top*scale-40,self.panY))
    local function screen(x,y)return size.x/2+self.panX+x*scale,size.y/2+self.panY+y*scale end
    for _,node in ipairs(self.nodes) do
        local x,y=screen(node.x-Model.cardWidth/2,node.y-Model.cardHeight/2)
        local visible=x<size.x and x+Model.cardWidth*scale>0 and y<size.y and y+Model.cardHeight*scale>0
        local card=self.cards[node.key]
        if visible and not card then card=self:card(node);self.cards[node.key]=card end
        -- Release offscreen render targets instead of retaining up to 256
        -- animated portraits while panning through a large family.
        if card and not visible then
            self.content:removeSubview(card);self.cards[node.key]=nil
        elseif card then position(card,x,y,2) end
    end
    for _,guide in ipairs(self.guides) do
        local x,y=screen(self.bounds.left,guide.y);position(guide.view,x,y,1)
    end
    local index=0
    local function line(x1,y1,x2,y2,color,hidden,thickness,z)
        index=index+1
        local x,y=screen(math.min(x1,x2),math.min(y1,y2))
        local view=self.lines[index];position(view,x-thickness/2,y-thickness/2,z)
        view.hidden=hidden;view.color=color
        view.size=mjm.vec2(math.abs(x2-x1)*scale+thickness,math.abs(y2-y1)*scale+thickness)
    end
    for order,edge in ipairs(self.edges) do
        local x1,x2=edge.topPort,edge.bottomPort
        local y1,y2=edge.upper.y+Model.cardHeight/2,edge.lower.y-Model.cardHeight/2
        local color=edge.role=="Mother" and maternal or (edge.role=="Father" and paternal or gold)
        local hidden=self.traceKey~=nil and edge.from.key~=self.traceKey and edge.to.key~=self.traceKey
        -- An opaque halo gives crossings a visible break instead of a false
        -- junction. Each edge is layered as a unit below every person card.
        for pass=1,2 do
            local ink=pass==1 and mjm.vec4(0.06,0.07,0.075,1) or color
            local thickness=pass==1 and 6 or (self.traceKey and 2.5 or 1.5)
            local z=order*0.002+pass*0.0005
            line(x1,y1,x1,edge.trackY,ink,hidden,thickness,z)
            line(x1,edge.trackY,x2,edge.trackY,ink,hidden,thickness,z)
            line(x2,edge.trackY,x2,y2,ink,hidden,thickness,z)
        end
    end
end
return Tree
