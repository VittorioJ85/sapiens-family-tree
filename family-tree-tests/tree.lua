local Archive=dofile(ROOT..'/FamilyTree/scripts/familyTree/archive.lua')
local db={data={}}
function db:dataForKey(key)return self.data[key]end
function db:setDataForKey(value,key)self.data[key]=value end
local archive=Archive.new(db)
local modules={['familyTree/nameSettings']={},['familyTree/familyStats']={},['common/sapienConstants']={}}
mjrequire=function(name)return assert(modules[name],name)end
local requests=dofile(ROOT..'/FamilyTree/scripts/familyTree/requests.lua')
local service={archive=archive,world={tribeIDForClientID=function(_,id)return id=='owner' and 't' or nil end},
    gom={getObjectWithID=function()end},isSapien=function()return false end}
local function person(id,extra)
    local row={id=id,name=id,tribeID='t'};for k,v in pairs(extra or {})do row[k]=v end;archive:observe(row)
end
person('root',{mother='mother',father='private'})
person('mother',{mother='grandmother'});person('grandmother',{mother='great-grandmother'})
person('great-grandmother');person('private',{tribeID='enemy',mother='secret'})
person('secret',{tribeID='enemy'})
for i=1,70 do person('child'..i,{mother='root'}) end
person('child1',{mother='corrected'})
person('child2',{tribeID='enemy'}) -- Historical membership remains deliberately accessible.
person('outside-child',{tribeID='enemy',mother='root'})
local touched={}
local get=archive.get
function archive:get(key)touched[key]=true;return get(self,key)end
local function request(action,id,relation,page)
    touched={};return requests:handle(service,'owner',{action=action,id=id,relation=relation,page=page})
end
local single=request('person','root')
assert(single.root.id=='root' and not single.root.mother and not touched['p:mother'])
local household=request('household','root')
assert(household.root.id=='root' and #household.parents==2 and #household.children==7 and household.nextPage==1)
assert(household.parents[1].id=='mother' and household.parents[2].status=='unknown')
assert(not touched['p:grandmother'] and not touched['p:child9'] and not touched['p:private'],'Initial family is bounded, private, and non-recursive')
assert(request('household','private').error)
assert(requests:handle(service,'intruder',{action='household',id='root'}).error)
assert(request('household','root',nil,1).error and request('household','root','parents').error)
-- Visual pages divide storage pages exactly: no gaps or duplicates at 32 entries.
local visited={}
for page=0,8 do
    local result=request('branch','root','children',page)
    for _,row in ipairs(result.rows) do assert(not visited[row.id]);visited[row.id]=true end
end
assert(not visited.child1 and visited.child2 and visited.child32 and visited.child33 and visited.child70)
local data=request('branch','root','parents')
assert(#data.rows==2 and data.rows[1].id=='mother' and data.rows[1].relationship=='Mother')
assert(data.rows[2].status=='unknown' and not data.rows[2].id)
assert(not touched['p:grandmother'] and not touched['p:private'] and not touched['p:child1'],'Do not read unopened generations')
data=request('branch','mother','parents');assert(data.rows[1].id=='grandmother' and not touched['p:great-grandmother'])
data=request('branch','root','children',0)
assert(#data.rows==7 and data.nextPage==1 and data.rows[1].id=='child2')
assert(not touched['p:child9'] and not touched['p:mother'])
data=request('branch','root','children',8);assert(#data.rows==6 and not data.nextPage and not touched['p:outside-child'])
assert(request('branch','private','parents').error)
assert(requests:handle(service,'intruder',{action='branch',id='root',relation='children'}).error)
for _,bad in ipairs({{action='branch',id='root',relation='siblings'},
    {action='branch',id='root',relation='parents',page=1},{action='branch',id='root',relation='parents',depth=10},
    {action='branch',id='root',relation='children',page=0/0},{action='branch',id='root',relation='children',page=math.huge},
    {action='person',id='root:foreign'},{action='person',id={}}, {action='family',id='root',relation='parents'}}) do
    assert(requests:handle(service,'owner',bad).error)
end
-- A completely private candidate page does not trigger a hidden full scan.
person('sparse')
for i=1,33 do person('hidden'..i,{tribeID='enemy',mother='sparse'})end
data=request('branch','sparse','children',0);assert(#data.rows==0 and data.nextPage==1 and not touched['p:hidden33'])
print('PASS tree endpoint: direct generations only, bounded child pages, corrected edges, historical access, private/unknown redaction and malformed-request rejection')

local Model=dofile(ROOT..'/FamilyTree/scripts/familyTree/treeModel.lua')
local pending,changes={},0
local tree=Model.new({id='root'},function(payload,callback)pending[#pending+1]={request=payload,callback=callback}end,
    function()changes=changes+1 end)
assert(#pending==0 and #tree:layout()==1,'Opening the canvas does not recursively request people')
tree:toggle(tree.root,'parents');assert(#pending==1 and pending[1].request.relation=='parents')
tree:toggle(tree.root,'parents');tree:toggle(tree.root,'parents');assert(#pending==1,'Pending requests are coalesced')
pending[1].callback({rows={{id='mother'},{id='father'}}})
local nodes=tree:layout();assert(#nodes==3)
local mother=tree.root.branches.parents.children[1]
tree:toggle(mother,'parents');pending[2].callback({rows={{id='gm'},{id='gf'}}})
assert(#tree:layout()==5 and #pending==2)
tree:toggle(tree.root,'children');pending[3].callback({rows={{id='child1'},{id='child2'}},nextPage=1})
assert(#tree:layout()==7)
tree:load(tree.root,'children');assert(pending[4].request.page==1)
pending[4].callback({rows={{id='child2'},{id='child3'}}})
assert(#tree.root.branches.children.children==3,'Deduplicate repeated page entries')
local child=tree.root.branches.children.children[1]
tree:toggle(child,'children');pending[5].callback({rows={{id='root'}}})
assert(#child.branches.children.children==0,'A return link must not allocate a card')
local count=#pending
tree:toggle(tree.root,'parents');assert(#tree:layout()==4)
tree:toggle(tree.root,'parents');assert(#pending==count and #tree:layout()==8,'Reopening uses already loaded branches')
local visible,edges=tree:layout()
assert(#edges==#visible-1)
for i,a in ipairs(visible)do
    for j,b in ipairs(visible)do
        if i~=j then assert(math.abs(a.y-b.y)>=Model.cardHeight or math.abs(a.x-b.x)>=Model.cardWidth,'Card overlap')end
    end
end
local grandparent=mother.branches.parents.children[1]
tree:toggle(grandparent,'parents');local stale=pending[#pending]
tree:collapseAll();stale.callback({rows={{id='obsolete'}}})
assert(tree.count==1 and tree.pending==0)
count=#pending;tree:toggle(tree.root,'parents');assert(#pending==count and tree.count==3,'Bounded cache survives Collapse all')
tree:close();assert(not tree.active)

-- A long history does not become one unbounded client view.
local model
model=Model.new({id='0'},function(payload,callback)
    callback({rows={{id=tostring(tonumber(payload.id)+1)}}})
end,function()end)
local node=model.root
for i=1,300 do
    model:toggle(node,'children')
    local b=node.branches.children
    if b.error then break end
    node=b.children[1]
end
assert(model.count==256 and #model.cacheKeys<=64 and #model:layout()==256)
model:collapseAll();assert(model.count==1)
local queue={}
model=Model.new({id='r'},function(payload,callback)queue[#queue+1]=callback end,function()end)
model:toggle(model.root,'children');queue[1]({rows={{id='a'},{id='b'},{id='c'},{id='d'},{id='e'}}})
for _,n in ipairs(model.root.branches.children.children)do model:toggle(n,'children')end
assert(model.pending==4 and #queue==5,'Bound concurrent branch work')
local before=model.count;model:close();queue[2]({rows={{id='late'}}});assert(model.count==before)
print('PASS tree model: lazy expansion, paged children, collapse/cache reuse, stable non-overlapping generations, cycles, stale replies, 256-card/64-page/4-request budgets')

-- Opening children on ancestors creates collateral branches without changing
-- the focus. Ordinary reverse links back to a path member are omitted.
local families={
    r={parents={'m','f'},children={'son'}},
    m={parents={'gm','gf'},children={'r','sister'}},
    f={children={'r','halfBrother'}},
    gm={children={'m','uncle'}},gf={children={'m','aunt'}},
    sister={children={'niece'}},uncle={children={'cousin'}},aunt={children={'otherCousin'}},
}
local calls=0
local mixed=Model.new({id='r'},function(payload,callback)
    calls=calls+1
    local rows={}
    for _,id in ipairs((families[payload.id] or {})[payload.relation] or {})do rows[#rows+1]={id=id}end
    callback({rows=rows})
end,function()end)
local function expand(node,direction)
    assert(mixed:canExpand(node,direction));mixed:toggle(node,direction)
    return node.branches[direction].children
end
local parents=expand(mixed.root,'parents')
local grandparents=expand(parents[1],'parents')
expand(mixed.root,'children')
local siblings=expand(parents[1],'children')
local halves=expand(parents[2],'children')
local uncles=expand(grandparents[1],'children')
local aunts=expand(grandparents[2],'children')
local nieces=expand(siblings[1],'children')
local cousins=expand(uncles[1],'children')
expand(aunts[1],'children')
local all,connections=mixed:layout()
assert(#connections==#all-1)
assert(siblings[1].y==mixed.root.y and halves[1].y==mixed.root.y)
assert(uncles[1].y==parents[1].y and cousins[1].y==mixed.root.y)
assert(nieces[1].generation==mixed.root.generation+1)
assert(#siblings==1 and siblings[1].row.id=='sister' and #uncles==1 and uncles[1].row.id=='uncle')
local before=calls
for i,a in ipairs(all)do
    for j,b in ipairs(all)do
        if i~=j then assert(math.abs(a.y-b.y)>=Model.cardHeight or math.abs(a.x-b.x)>=Model.cardWidth,'Collateral cards overlap')end
    end
end
mixed:toggle(parents[1],'children')
local shown={};for _,n in ipairs(mixed:layout())do shown[n.key]=true end
assert(not shown[siblings[1].key] and not shown[nieces[1].key] and shown[uncles[1].key])
mixed:toggle(parents[1],'children');assert(calls==before,'Reopening ancestor children reuses their nested branch cache')
mixed:toggle(mixed.root,'parents')
assert(#mixed:layout()==2,'Folding ancestors also folds all attached collateral branches')
print('PASS ancestor children: independent branches, siblings/half-siblings/uncles/cousins at correct generations, no overlaps or recursive return links, subtree collapse and lazy cache reuse')

-- Omission must happen before the capacity check and must not lose the next
-- page. Cache entries remain path-independent; legitimate repeats still work.
local queue={}
local filtered=Model.new({id='self'},function(request,callback)queue[#queue+1]={request=request,callback=callback}end,function()end)
filtered.maxNodes=1
filtered:toggle(filtered.root,'children')
queue[1].callback({rows={{id='self'},{id='self'}},nextPage=1})
assert(filtered.count==1 and filtered.root.branches.children.nextPage==1 and not filtered.root.branches.children.error)
local cards,lines,bounds=filtered:layout()
assert(#cards==1 and #lines==0 and bounds.left==-Model.cardWidth/2 and bounds.right==Model.cardWidth/2)
filtered.maxNodes=3;filtered:load(filtered.root,'children')
queue[2].callback({rows={{id='new'},{id='new'}}})
assert(filtered.count==2 and #filtered.root.branches.children.children==1)
filtered:collapseAll();filtered:toggle(filtered.root,'children')
assert(#queue==2 and filtered.count==1,'Cached pages must filter return links again')
local shared={rows={{id='self'},{id='other'}}}
filtered:remember('parent:children:0',shared)
filtered:toggle(filtered.root,'parents');queue[3].callback({rows={{id='parent'}}})
local p=filtered.root.branches.parents.children[1]
filtered:toggle(p,'children')
assert(#p.branches.children.children==1 and p.branches.children.children[1].row.id=='other')
assert(#shared.rows==2 and filtered.cache['parent:children:0'].rows[1].id=='self','Do not mutate cached response rows')
local alternative=Model.new({id='differentRoot'},function()error('Expected cache hit')end,function()end)
alternative:remember('differentRoot:parents:0',{rows={{id='parent'}}})
alternative:remember('parent:children:0',filtered.cache['parent:children:0'])
alternative:toggle(alternative.root,'parents')
local parent=alternative.root.branches.parents.children[1];alternative:toggle(parent,'children')
assert(#parent.branches.children.children==2,'The same ID is legitimate on a different path')
print('PASS omitted return links: no cards/lines/space/budget usage, preserved pagination, page deduplication and path-independent cache reuse')

-- Parents can now be opened on descendants, including after several direction
-- reversals through a second parent's family. Every open occurrence must render.
local records={
    focus={children={'child'},parents={'ancestor'}},
    child={parents={'focus','otherParent'}},
    otherParent={parents={'grandparent'},children={'child','halfSibling'}},
    halfSibling={parents={'otherParent','anotherParent'}},
    anotherParent={parents={'greatParent'}},
    ancestor={children={'focus','sibling'}},
    sibling={parents={'ancestor','secondAncestor'}},
}
local requestsMade=0
local both=Model.new({id='focus'},function(request,callback)
    requestsMade=requestsMade+1
    local rows={};for _,id in ipairs((records[request.id] or {})[request.relation] or {})do rows[#rows+1]={id=id}end
    callback({rows=rows})
end,function()end)
local function open(node,direction)
    assert(both:canExpand(node,direction));both:toggle(node,direction)
    local rows=node.branches[direction].children
    assert(#rows==1,'Known return links must be omitted')
    return rows[1]
end
local child=open(both.root,'children')
local other=open(child,'parents')
local gp=open(other,'parents')
local half=open(other,'children')
local another=open(half,'parents')
local great=open(another,'parents')
local ancestor=open(both.root,'parents')
local sibling=open(ancestor,'children')
open(sibling,'parents')
local rows,edges=both:layout()
assert(#rows==both.count and #edges==#rows-1,'All nested reversals must be placed exactly once')
local seen={}
for i,a in ipairs(rows)do
    assert(not seen[a.key]);seen[a.key]=true
    for j,b in ipairs(rows)do
        if i~=j then assert(math.abs(a.y-b.y)>=Model.cardHeight or math.abs(a.x-b.x)>=Model.cardWidth,'Reversed-branch overlap')end
    end
end
for _,edge in ipairs(edges)do
    assert(edge.to.generation-edge.from.generation==(edge.to.direction=='parents' and -1 or 1))
end
assert(other.generation==0 and gp.generation==-1 and half.generation==1 and great.generation==-1)
local prior=requestsMade
both:toggle(child,'parents')
local visible={};for _,n in ipairs(both:layout())do visible[n.key]=true end
assert(visible[child.key] and visible[sibling.key] and not visible[other.key] and not visible[great.key])
both:toggle(child,'parents');assert(requestsMade==prior and #both:layout()==both.count)
assert(not both:canExpand({row={status='unknown'}},'parents'))
assert(not both:canExpand(child,'unsupported'))
print('PASS descendant parents: second-parent families, repeated direction changes, correct generations, unique non-overlapping placement, collapse/cache reuse and loop filtering')
