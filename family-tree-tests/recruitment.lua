local modules = {['familyTree/nameCatalog']=CATALOG,
    ['common/gameObject']={types={sapien={index=1}}},
    ['common/sapienConstants']={familyRelationshipTypes={mother=1,father=2,biologicalChild=4}}}
mjrequire=function(name) return assert(modules[name],name) end
for _,name in ipairs({'archive','nameSettings','surnames','familyStats','requests','service'}) do
    modules['familyTree/'..name]=dofile(ROOT..'/FamilyTree/scripts/familyTree/'..name..'.lua')
end
local service, names = modules['familyTree/service'], modules['familyTree/surnames']
local data, objects = {}, {}
local db={dataForKey=function(_,key) return data[key] end,setDataForKey=function(_,v,key) data[key]=v end}
local gom={getObjectWithID=function(_,id) return objects[id] end,saveObject=function() end}
function gom:callFunctionForAllSapiensInTribe(tribe,fn)
    for _,p in pairs(objects) do if p.sharedState.tribeID==tribe then fn(p) end end
end
local world={getDatabase=function() return db end,clientIDForTribeID=function(_,id) return id=='home' and 'player' or 'server' end}
mj={serverClientID='server'}
service:init(world,gom)
local cfg={automatic=true,cultures={custom=true},customNames={'Alpha','Beta','Gamma'}}
service.archive:put('nameSettings:home',cfg)
local function person(id,tribe,nomad)
    local state={name=id,tribeID=tribe,nomad=nomad}
    function state:set(k,v) self[k]=v end
    local p={uniqueID=id,objectTypeIndex=1,sharedState=state,lazyPrivateState={relationships={}}}
    objects[id]=p; return p
end
local sapiens={createChildFromMother=function() end,updateStatusForFriendsOfDyingSapien=function() end,removeSapien=function() end}
function sapiens:recruitComplete(p,tribe)
    local source=p.sharedState.tribeID
    if p.sharedState.nomad then
        gom:callFunctionForAllSapiensInTribe(source,function(member) member.sharedState.tribeID=tribe; member.sharedState.nomad=nil end)
    else p.sharedState.tribeID=tribe end
end
dofile(ROOT..'/FamilyTree/scripts/server/serverSapien.lua'):onload(sapiens)
-- More than one archive page forces asynchronous naming and a reload before completion.
for i=1,100 do service.archive:observe({id='old'..i,tribeID='home',status='deceased',deathTime=1}) end
local first,second=person('a','nomads',true),person('b','nomads',true)
sapiens:recruitComplete(second,'home')
assert(service.archive:person('a').surnameGroup==service.archive:person('b').surnameGroup)
service:observe(first)
assert(not first.sharedState.familyTreeSurname)
service:init(world,gom); service:enqueue(first); service:enqueue(second)
for _=1,10 do service:drain() end
local surname=first.sharedState.familyTreeSurname
assert(surname and second.sharedState.familyTreeSurname==surname)
local stats=modules['familyTree/familyStats']
assert(stats:lineage('a',service.archive)==stats:lineage('b',service.archive))
assert(not service.archive:person('a').father and not service.archive:person('b').mother)
local third,fourth=person('c','next',true),person('d','next',true)
sapiens:recruitComplete(third,'home'); service:drain()
assert(third.sharedState.familyTreeSurname==fourth.sharedState.familyTreeSurname)
assert(third.sharedState.familyTreeSurname~=surname, 'different groups prefer unused names')
-- A child can inherit before a freshly recruited parent's queue entry is processed.
local parent,partner=person('e','last',true),person('f','last',true)
sapiens:recruitComplete(parent,'home')
local child=person('child','home')
child.lazyPrivateState.relationships.e={familyRelationshipType=2}
service:observe(child); service:drain()
assert(child.sharedState.familyTreeSurname==parent.sharedState.familyTreeSurname)
assert(stats:lineage('child',service.archive)==stats:lineage('e',service.archive))
-- Manual names remain exact and supply the shared name for other members.
local manual,relative=person('g','manual',true),person('h','manual',true)
manual.sharedState.name='Given Custom'; names:manual(manual,service.archive,gom)
sapiens:recruitComplete(relative,'home'); service:drain()
assert(manual.sharedState.name=='Given Custom' and relative.sharedState.familyTreeSurname=='Custom')
manual.sharedState.name='Given Edited'; service:observe(manual)
assert(manual.sharedState.name=='Given Edited')
-- Individual settled recruitment must not label the remaining source tribe.
local solo,stays=person('solo','settled'),person('stays','settled')
sapiens:recruitComplete(solo,'home'); service:drain()
assert(not service.archive:person('solo').surnameGroup and stays.sharedState.tribeID=='settled')
assert(not stays.sharedState.familyTreeSurname)
cfg.automatic=false; service.archive:put('nameSettings:home',cfg)
local off1,off2=person('off1','off',true),person('off2','off',true)
sapiens:recruitComplete(off1,'home'); service:drain()
assert(off1.sharedState.name=='off1' and off2.sharedState.name=='off2')
assert(not service.archive:person('off1').surnameGroup)
cfg.automatic=true; service.archive:put('nameSettings:home',cfg)
local localMember,outsider=person('partial','home'),person('outsider','elsewhere')
service:recruitedGroup({localMember,outsider},'home')
assert(not service.archive:person('outsider'), 'never mark members that did not join')
service:recruitedGroup({outsider,person('npc2','elsewhere')},'elsewhere')
assert(not service.archive:person('outsider'), 'NPC tribes must not receive naming groups')
print('PASS recruitment: shared names, distinct groups, bounded deferred naming, reload, inheritance, family counts, manual protection, individual recruits and OFF')
