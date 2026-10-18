local Archive=dofile(ROOT..'/FamilyTree/scripts/familyTree/archive.lua')
local modules={['familyTree/nameCatalog']=CATALOG,['familyTree/archive']=Archive}
mjrequire=function(name) return assert(modules[name],name) end
local Names=dofile(ROOT..'/FamilyTree/scripts/familyTree/surnames.lua')
local Model=dofile(ROOT..'/FamilyTree/scripts/familyTree/nameSettings.lua')
local function db()
    return {data={},dataForKey=function(self,k) return self.data[k] end,
        setDataForKey=function(self,v,k) self.data[k]=v end}
end
local database=db()
local archive=Archive.new(database)
local objects={}
local gom={getObjectWithID=function(_,id) return objects[id] end,saveObject=function() end}
function gom:callFunctionForAllSapiensInTribe(tribe,fn)
    for _,p in pairs(objects) do if p.sharedState.tribeID==tribe then fn(p) end end
end
local function person(id,tribe)
    local state={name=id,tribeID=tribe or 't'}
    function state:set(k,v) self[k]=v end
    local p={objectTypeIndex=1,uniqueID=id,sharedState=state,lazyPrivateState={relationships={}}}
    objects[id]=p
    archive:observe({id=id,name=id,tribeID=state.tribeID,status='lastSeenAlive'})
    return p
end
local cfg=assert(Model:validate({automatic=true,cultures={ancientEgyptian=true},customNames={}}))
local initials={}
assert(#CATALOG.names.ancientEgyptian==128)
for _,name in ipairs(CATALOG.names.ancientEgyptian) do
    local initial=name:sub(1,1); initials[initial]=(initials[initial] or 0)+1
end
for letter=65,90 do assert(initials[string.char(letter)]==4 or initials[string.char(letter)]==5) end
local seen={}
for i=1,128 do
    local p=person('founder'..i)
    local surname=Names:apply(p,archive,gom,{},cfg)
    assert(surname and not seen[surname],'duplicate before all 128 names used')
    seen[surname]=true
end
local duplicate=Names:apply(person('founder129'),archive,gom,{},cfg)
assert(seen[duplicate],'duplicate allowed after pool exhausted')
-- Reload builds the index lazily, at most 32 archive rows per request.
archive=Archive.new(database)
assert(not archive.nameUsage)
local candidate=person('afterReload')
assert(not Names:apply(candidate,archive,gom,{},cfg),'defer while archive index is incomplete')
assert(archive.nameUsage.t.page==1)
for _=1,10 do if Names:apply(candidate,archive,gom,{},cfg) then break end end
assert(candidate.sharedState.familyTreeSurname)
-- Excluded entries do not have to be used before an enabled pool can repeat.
local short={automatic=true,cultures={custom=true},customNames={'Alpha','Beta','Gamma'},excludedNames={Gamma=true}}
for i=1,2 do assert(Names:apply(person('short'..i,'short'),archive,gom,{},short)) end
local repeated=Names:apply(person('short3','short'),archive,gom,{},short)
assert(repeated=='Alpha' or repeated=='Beta')
-- Loaded members not yet archived and manual renames reserve their current name.
objects.pending={objectTypeIndex=1,uniqueID='pending',sharedState={tribeID='new',name='Player Alpha',familyTreeSurname='Old',familyTreeLastName='Player Old'}}
assert(Names:apply(person('newFounder','new'),archive,gom,{},short)=='Beta')
-- Unloaded active members reserve names too; removed/dead/other-tribe members do not.
archive:observe({id='unloaded',tribeID='offscreen',surname='Alpha',status='lastSeenAlive'})
assert(Names:apply(person('offscreenFounder','offscreen'),archive,gom,{},short)=='Beta')
archive:observe({id='unloaded',status='deceased',deathTime=1})
assert(Names:apply(person('offscreenNext','offscreen'),archive,gom,{},short)=='Alpha')
local named=objects.offscreenNext
named.sharedState.name='Changed Gamma'; Names:manual(named,archive,gom)
assert(Names:apply(person('released','offscreen'),archive,gom,{},short)=='Alpha')
-- Even if another family already has it, an inherited surname must stay shared.
local child=person('child','offscreen')
child.lazyPrivateState.relationships={released={familyRelationshipType=2}}
assert(Names:apply(child,archive,gom,{father=2,mother=1},short)=='Alpha')
-- Real service retries deferred assignment through its bounded normal queue.
modules['familyTree/surnames']=Names; modules['familyTree/nameSettings']=Model
modules['familyTree/familyStats']=dofile(ROOT..'/FamilyTree/scripts/familyTree/familyStats.lua')
modules['common/sapienConstants']={familyRelationshipTypes={},getAgeValue=function() return 1 end}
modules['common/gameObject'] = {types={sapien={index=1}}}
modules['familyTree/requests'] = dofile(ROOT .. '/FamilyTree/scripts/familyTree/requests.lua')
local service=dofile(ROOT..'/FamilyTree/scripts/familyTree/service.lua')
mj={serverClientID='server'}
local world={getDatabase=function() return database end,clientIDForTribeID=function() return 'player' end}
service:init(world,gom)
service.archive:put('nameSettings:large',short)
for i=1,100 do service.archive:observe({id='old'..i,tribeID='large',status='deceased',deathTime=1}) end
local deferred=person('deferred','large')
service:observe(deferred)
assert(not deferred.sharedState.familyTreeSurname and service.queued.deferred)
for _=1,10 do service:drain() end
assert(deferred.sharedState.familyTreeSurname and not service.queued.deferred)
-- Disabling naming during a pending scan must stop retries without changing names.
service:reset(); service:init(world,gom)
local paused=person('paused','large')
service:observe(paused)
assert(service.queued.paused)
service.archive:put('nameSettings:large',Model:defaults())
service:drain()
assert(not service.queued.paused and not paused.sharedState.familyTreeSurname)
print('PASS unique surnames: balanced Egyptian initials, 128 unique founders, exhaustion, exclusions, manual edits, unloaded members, deaths, inheritance, reload, bounded retry and disabled naming')
