-- Render-tree and input tests. Native drawing is simulated; clipping, hitbox
-- positions, view lifecycle and real mod callbacks are exercised together.
local modules,pending,timers={},{},{}
local function view(parent)
    local v={size={x=1140,y=640},children={}}
    function v:removeAllSubviews()self.children={}end
    function v:removeSubview(child)
        for i,item in ipairs(self.children)do if item==child then table.remove(self.children,i);return end end
        error('Subview not found')
    end
    function v:setClipChildren(value)self.clips=value end
    if parent then parent.children[#parent.children+1]=v end
    return v
end
View,TextView,ColorView={new=view},{new=view},{new=view}
ViewPosition=function(...)return {...}end;Font=function(_,size)return{size=size}end
mj={textColor={1,1,1,1},disabledTextColor={0.4,0.4,0.4,1}}
modules['common/mjm']={vec2=function(x,y)return{x=x,y=y}end,vec3=function(x,y,z)return{x=x,y=y,z=z}end,
    vec4=function(...)return{...}end}
modules['mainThread/ui/uiCommon/uiCommon']={fontName='test'}
modules['mainThread/ui/uiCommon/uiGameObjectView']={types={backgroundCircle=1},
    create=function(_,parent,size,kind)
        assert(kind==1);local v=view(parent);v.size=size;v.portrait=true;return v
    end,
    setObject=function(_,v,object)
        assert(object.uniqueID=='root' and object.sharedState and object.objectTypeIndex==1)
        v.personID=object.uniqueID
    end}
local buttons={types={standard_10x3=1},create=function(_,parent,size)local v=view(parent);v.size=size;v.button=true;return v end,
    setText=function(_,v,t)v.text=t end,setDisabled=function(_,v,t)v.disabled=t end,
    setClickFunction=function(_,v,fn)v.click=fn end,setIconModel=function(_,v,icon)v.icon=icon end}
modules['mainThread/ui/uiCommon/uiStandardButton']=buttons
modules['common/timer']={addCallbackTimer=function(_,delay,fn)local id={fn=fn};timers[id]=true;return id end,
    removeTimer=function(_,id)timers[id]=nil end}
modules['mainThread/logicInterface']={callServerFunction=function(_,name,data,callback)
    assert(name=='familyTreeRequest');pending[#pending+1]={data=data,callback=callback}
end}
modules['mainThread/playerSapiens']={getInfo=function(_,id)
    if id=='root' then return{uniqueID=id,objectTypeIndex=1,sharedState={tribeID='t'}}end
end}
modules['familyTree/treeModel']=dofile(ROOT..'/FamilyTree/scripts/familyTree/treeModel.lua')
mjrequire=function(name)return assert(modules[name],name)end
modules['familyTree/requestScope']=dofile(ROOT..'/FamilyTree/scripts/familyTree/requestScope.lua')
local Tree=dofile(ROOT..'/FamilyTree/scripts/familyTree/treeView.lua')
modules['familyTree/treeView']=Tree
local owner=dofile(ROOT..'/FamilyTree/scripts/familyTree/ui.lua')
local parent=view()
owner:init(parent);owner:show({uniqueID='root'})
pending[#pending].callback({root={id='root',name='Root Aurelius',tribeID='t',age=68},ancestors={},children={},childCount=0})
pending[#pending].callback({living=5,deceased=3,unknown=1,done=true,resolved=true,oldest={id='root',name='Root Aurelius',age=68,tribeID='t'}})
local function button(parent,label)
    for _,v in ipairs(parent.children)do
        if v.button then
            local text=v.text
            if text=='' and v.children[1] then text=v.children[1].text end
            if text==label then return v end
        end
    end
    error('Missing button '..label)
end
local tree=owner.tree
assert(tree and not owner.listMode and tree.viewport.clips and tree.oldestID=='root')
-- Reset the seeded fixture to exercise manual branch RPCs and failure handling.
tree.model:collapseAll();tree.model.cache={};tree.model.cacheKeys={}
local requestCount=#pending
assert(#tree.nodes==1 and #pending==requestCount)
local root=tree.model.root
local function labels(parent,result)
    result=result or {}
    for _,v in ipairs(parent.children)do
        if v.text then result[v.text]=true end
        labels(v,result)
    end
    return result
end
assert(labels(tree.cards[root.key])['Alive | age 68'],'Living age must remain visible')
local portrait
for _,v in ipairs(tree.cards[root.key].children)do if v.portrait then portrait=v end end
assert(portrait and portrait.personID=='root' and portrait.masksEvents==false)
button(tree.cards[root.key],'+ Parents').click()
assert(pending[#pending].data.action=='branch' and pending[#pending].data.relation=='parents')
pending[#pending].callback({rows={{id='mother',name='Mother Aurelia',relationship='Mother',tribeID='t'},
    {id='father',name='Father Aurelius',status='deceased',relationship='Father',tribeID='t',
        birthDate='Year 2, Day 3',deathDate='Year 8, Day 4'}}})
local dateLabels=labels(tree.cards[root.branches.parents.children[2].key])
assert(dateLabels['Born: Year 2, Day 3'] and dateLabels['Died: Year 8, Day 4'])
assert(dateLabels['No portrait'],'Historical people without appearance data get an honest placeholder')
local mother=root.branches.parents.children[1]
button(tree.cards[mother.key],'+ Parents').click()
pending[#pending].callback({rows={{id='gm',name='Grandmother',tribeID='t'}, {status='unknown',relationship='Father'}}})
tree:zoom(0.6)
assert(tree.scale==0.6 and tree.zoomLabel.text=='60%' and #tree.nodes==5)
local rootCard=tree.cards[root.key]
local oldX,oldY=rootCard.baseOffset.x,rootCard.baseOffset.y
tree.viewport.mouseDown(0,{x=100,y=100})
tree.viewport.mouseDragged({x=145,y=75});tree.viewport.mouseUp()
assert(rootCard.baseOffset.x==oldX+45 and rootCard.baseOffset.y==oldY-25,'Native mouse Y is bottom-up')
local rootPos=rootCard.baseOffset.x
tree.viewport.mouseDragged({x=500,y=500});assert(rootCard.baseOffset.x==rootPos,'Mouse release stops dragging')
local before=#pending
tree.viewport.mouseWheel({x=550,y=220},{y=1})
assert(tree.scale>0.6 and #pending==before,'Camera changes are client-only')
tree:zoom(999);assert(tree.scale==1.3);tree:zoom(-1);assert(tree.scale==0.2);tree:zoom(0.6)
tree:center();assert(tree.panX==0 and tree.panY==0)
-- No buttons overlap inside any visible card, including dual retry controls.
local function checkCards()
    for _,card in pairs(tree.cards)do
        local boxes={}
        for _,v in ipairs(card.children)do
            if v.portrait then
                assert(v.personID=='root' and not v.masksEvents)
                assert(math.abs(v.size.x-64*tree.scale)<0.001)
                assert(v.baseOffset.x+v.size.x<=card.size.x and -v.baseOffset.y+v.size.y<121*tree.scale)
                for _,column in ipairs(card.children)do
                    if column.clips then
                        assert(column.baseOffset.x+column.size.x<=v.baseOffset.x,'Text must not overlap portrait')
                    end
                end
            end
            if v.button then
                local x,y=v.baseOffset.x,-v.baseOffset.y
                assert(x>=0 and y>=0 and x+v.size.x<=card.size.x+0.001 and y+v.size.y<=card.size.y+0.001)
                for _,b in ipairs(boxes)do
                    assert(x>=b.x2-0.001 or x+v.size.x<=b.x1+0.001 or y>=b.y2-0.001 or y+v.size.y<=b.y1+0.001,'Overlapping card buttons')
                end
                boxes[#boxes+1]={x1=x,y1=y,x2=x+v.size.x,y2=y+v.size.y}
            end
        end
    end
end
checkCards()
-- Moving a card entirely out of view releases its render target; returning
-- recreates it from follower data without any additional RPC.
local savedX=root.x;local oldCard=tree.cards[root.key];local rpcCount=#pending
root.x=100000;tree:move();assert(not tree.cards[root.key])
for _,v in ipairs(tree.content.children)do assert(v~=oldCard)end
root.x=savedX;tree:move();assert(tree.cards[root.key] and tree.cards[root.key]~=oldCard and #pending==rpcCount)
button(tree.cards[mother.key],'+ Children').click()
assert(pending[#pending].data.id=='mother' and pending[#pending].data.relation=='children')
pending[#pending].callback({rows={{id='root',name='Root Aurelius',tribeID='t'},
    {id='sister',name='Sister Aurelia',tribeID='t'}}})
assert(#mother.branches.children.children==1 and mother.branches.children.children[1].row.id=='sister')
assert(mother.branches.children.children[1].y==root.y and owner.id=='root')
checkCards()
local ancestorRequests=#pending
button(tree.cards[mother.key],'- Children').click()
button(tree.cards[mother.key],'+ Children').click()
assert(#pending==ancestorRequests,'Ancestor children reopen locally')
button(tree.cards[root.key],'+ Children').click()
local timeout;for id in pairs(timers)do timeout=id end
timeout.fn();assert(root.branches.children.error)
button(tree.cards[root.key],'Retry').click()
pending[#pending].callback({rows={{id='kid',name='Child Aurelius',tribeID='t'}},nextPage=1})
button(tree.cards[root.key],'More').click()
assert(pending[#pending].data.page==1)
pending[#pending].callback({rows={}})
checkCards()
local kid=root.branches.children.children[1]
button(tree.cards[kid.key],'+ Parents').click()
assert(pending[#pending].data.id=='kid' and pending[#pending].data.relation=='parents')
pending[#pending].callback({rows={{id='root',name='Root Aurelius',tribeID='t'},
    {id='coParent',name='Other Parent',tribeID='t'}}})
assert(#kid.branches.parents.children==1 and kid.branches.parents.children[1].row.id=='coParent')
assert(kid.branches.parents.children[1].y==root.y and owner.id=='root')
checkCards()
local parentRequests=#pending
-- Trace must remove unrelated buses without fetching people or changing focus.
button(tree.cards[kid.key],'Trace').click()
local visibleLines=0;for _,line in ipairs(tree.lines)do if not line.hidden then visibleLines=visibleLines+1 end end
assert(visibleLines==12 and #pending==parentRequests and owner.id=='root')
button(tree.cards[kid.key],'All').click()
for _,line in ipairs(tree.lines)do assert(not line.hidden)end
button(parent,'Fit').click();assert(#pending==parentRequests)
for _,node in ipairs(tree.nodes)do assert(tree.cards[node.key] and not tree.cards[node.key].hidden)end
checkCards()
button(tree.cards[kid.key],'- Parents').click();button(tree.cards[kid.key],'+ Parents').click()
assert(#pending==parentRequests,'Descendant parents reopen locally')
local count=#pending
button(tree.cards[root.key],'- Parents').click();button(tree.cards[root.key],'+ Parents').click()
assert(#pending==count,'Reopening does not refetch')
local cameraX,cameraY,nodeCount=tree.panX,tree.panY,#tree.nodes
owner:requestStats({root=root.row},owner.serial,0,{living=0,deceased=0,unknown=0})
pending[#pending].callback({living=5,deceased=3,unknown=0,done=true,resolved=true,
    oldest={id='mother',name='Mother Aurelia',tribeID='t',age=90}})
assert(owner.tree==tree and #tree.nodes==nodeCount and tree.panX==cameraX and tree.panY==cameraY)
-- Focusing an already visible person requests only that person as root; the
-- existing family-statistics request is separate from genealogy expansion.
button(parent,'Oldest: Mother Aurelia').click()
assert(not tree.active and owner.id=='mother' and pending[#pending].data.action=='household')
pending[#pending].callback({root={id='mother',name='Mother Aurelia',tribeID='t'}})
assert(owner.tree and owner.tree~=tree and #owner.tree.nodes==1)
pending[#pending].callback({living=3,deceased=1,unknown=0,done=true,resolved=true})
button(parent,'Archive').click()
assert(owner.listMode and not owner.tree and pending[#pending].data.action=='list')
pending[#pending].callback({rows={},count=0})
button(parent,'Back').click()
assert(not owner.listMode and pending[#pending].data.action=='household')
pending[#pending].callback({root={id='mother',name='Mother Aurelia',tribeID='t'},parents={},children={},nextPage=1})
pending[#pending].callback({living=3,deceased=1,unknown=0,done=true,resolved=true})
tree=owner.tree
button(tree.cards[tree.model.root.key],'More').click();local late=pending[#pending]
owner:hide();assert(not tree.active and not next(timers))
assert(not next(tree.cards) and #tree.content.children==0,'Closing must release portrait views')
late.callback({rows={{id='stale',name='Stale'}}});assert(tree.model.count==1)
owner:show({uniqueID='other'});assert(not owner.listMode and not owner.tree)
owner.history={{id='root',listMode=true,page=2,relation='children'}}
owner:popUI();assert(owner.listMode and pending[#pending].data.action=='list','Back can restore an archive page')
owner:render({error='Person unavailable'})
assert(not owner.tree,'Error recovery must leave usable navigation controls')
-- The installed companion mod clones controller methods for its grave panel.
-- Verify the new default tree works there without altering the living UI owner.
modules['familyTree/ui']=owner
modules['common/modManager']={enabledModDirNamesAndVersionsByType={world={{name='FamilyTree'}}},modInfosByTypeByDirName={world={}}}
local companionPath=ROOT..'/RitesAndRemembrance/scripts/ritesRemembrance/familyLink.lua'
local companionFile=io.open(companionPath,'r')
if companionFile then
companionFile:close()
local link=dofile(companionPath)
local inspect={modalPanelView=view(),setModalPanelTitleAndObject=function()end,
    showModalPanelView=function(_,container)container.hidden=false end}
local ownerView=owner.view
link.open(inspect,{id='deceased',name='Ancestor'})
assert(pending[#pending].data.action=='household' and pending[#pending].data.id=='deceased')
pending[#pending].callback({root={id='deceased',name='Ancestor',status='deceased',tribeID='t'},parents={},children={}})
assert(owner.view==ownerView and link.container and #link.container.children>0)
local staleStats=pending[#pending];link.close()
staleStats.callback({living=1,deceased=1,unknown=0,done=true,resolved=true})
assert(not link.container and owner.view==ownerView)
print('PASS companion integration: real Rites and Remembrance family link, independent controller and stale-response isolation')
else print('SKIP optional companion integration: Rites and Remembrance source not present') end
print('PASS tree UI: unified Family, clipped cards, archive/settings navigation, panning/zoom, hitboxes, retry, cache, household focus, stable camera on stats, oldest navigation and stale replies')
print('PASS tree portraits: current follower identity, clipped text, scaled bounds, honest historical fallback, offscreen release/recreation without RPCs and close cleanup (mock native drawing)')
