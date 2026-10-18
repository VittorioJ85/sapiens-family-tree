local Archive = dofile(ROOT .. '/FamilyTree/scripts/familyTree/archive.lua')
local Names = dofile(ROOT .. '/FamilyTree/scripts/familyTree/surnames.lua')
local function copy(v)
    if type(v) ~= 'table' then return v end
    local out = {}; for k,x in pairs(v) do out[k] = copy(x) end; return out
end
local db = {values = {}}
function db:dataForKey(k) return copy(self.values[k]) end
function db:setDataForKey(v,k) self.values[k] = copy(v) end
local objects, saves = {}, 0
local gom = {getObjectWithID=function(_,id) return objects[id] end,
    saveObject=function() saves=saves+1 end}
local types = {mother=1,father=2,biologicalChild=4}
local function person(id, father, mother)
    local state={name=id,tribeID='tribe'}
    function state:set(k,v) self[k]=v end
    local rels={}
    if father then rels[father]={familyRelationshipType=2} end
    if mother then rels[mother]={familyRelationshipType=1} end
    local p={objectTypeIndex=1,uniqueID=id,sharedState=state,lazyPrivateState={relationships=rels}}
    objects[id]=p; return p
end
local a=Archive.new(db)
local grand=person('grand')
local father=person('father','grand')
local child=person('child','father')
local surname=Names:apply(child,a,gom,types)
assert(surname==Names:apply(father,a,gom,types))
assert(surname==Names:apply(grand,a,gom,types))
assert(child.sharedState.name=='child '..surname)
local before=saves
Names:apply(child,a,gom,types); assert(saves==before)
local b=Archive.new(db)
assert(Names:apply(child,b,gom,types)==surname)
objects.father=nil
a:observe({id='father',surname=surname,deathTime=42,status='deceased'})
assert(Names:apply(person('orphan','father'),a,gom,types)==surname)
local mother=person('mother')
local maternal=Names:apply(mother,a,gom,types)
assert(Names:apply(person('fallback',nil,'mother'),a,gom,types)==maternal)
local founder=person('founder')
local assigned=Names:apply(founder,a,gom,types)
founder.sharedState.tribeID='other'
assert(Names:apply(founder,a,gom,types)==assigned)
founder.sharedState.name='Renamed'
Names:apply(founder,a,gom,types)
assert(founder.sharedState.name=='Renamed')
Names:apply(founder,a,gom,types)
assert(founder.sharedState.name=='Renamed')
local missing=Names:apply(person('missing-child','unloaded-father'),a,gom,types)
assert(Names:apply(person('unloaded-father'),a,gom,types)==missing)
person('cycle-a','cycle-b'); person('cycle-b','cycle-a')
assert(Names:apply(objects['cycle-a'],a,gom,types)==Names:apply(objects['cycle-b'],a,gom,types))
-- Actual service: player tribes only, existing archive upgrades, actual shared-state persistence.
mj={serverClientID='server'}
local constants={familyRelationshipTypes=types,getAgeValue=function() return 20 end}
local modules={['familyTree/nameCatalog']=CATALOG,['familyTree/archive']=Archive,['familyTree/surnames']=Names,['common/sapienConstants']=constants}
modules['familyTree/familyStats']=dofile(ROOT .. '/FamilyTree/scripts/familyTree/familyStats.lua')
modules['familyTree/nameSettings']=dofile(ROOT .. '/FamilyTree/scripts/familyTree/nameSettings.lua')
mjrequire=function(name) return assert(modules[name],name) end
modules['common/gameObject'] = {types={sapien={index=1}}}
modules['familyTree/requests'] = dofile(ROOT .. '/FamilyTree/scripts/familyTree/requests.lua')
local service=dofile(ROOT..'/FamilyTree/scripts/familyTree/service.lua')
local world={getDatabase=function() return db end,getWorldTime=function() return 100 end,
    clientIDForTribeID=function(_,id) return id=='tribe' and 'player' or 'server' end}
service:init(world,gom)
-- New tribes have no automatic assignments, including when a parent has a surname.
local freshSettings=modules['familyTree/nameSettings']:get(service.archive,'tribe')
assert(not freshSettings.automatic and next(freshSettings.cultures)==nil)
local freshRecruit=person('fresh-recruit')
local freshChild=person('fresh-child','grand')
service:enqueue(freshRecruit); service:drain()
service:observe(freshChild)
assert(freshRecruit.sharedState.name=='fresh-recruit' and not freshRecruit.sharedState.familyTreeSurname)
assert(freshChild.sharedState.name=='fresh-child' and not freshChild.sharedState.familyTreeSurname)
assert(service.archive:person('fresh-child').father=='grand','genealogy still records while naming is disabled')
service:init(world,gom); service:observe(freshChild)
assert(freshChild.sharedState.name=='fresh-child','reload must not enable naming')
-- Preserve explicit settings saved by older versions.
service.archive:put('nameSettings:tribe',{automatic=true,culture='mixed',customNames={}})
service:init(world,gom)
local recruit=person('recruit')
service:observe(recruit)
assert(recruit.sharedState.familyTreeSurname)
assert(service.archive:person('recruit').name==recruit.sharedState.name)
local npc=person('npc'); npc.sharedState.tribeID='npc-tribe'
service:observe(npc); assert(npc.sharedState.name=='npc')
local babyObject=person('new-child',nil,'mother')
service:observe(babyObject,{father='father'})
assert(babyObject.sharedState.familyTreeSurname==surname)
service:died(babyObject)
assert(service.archive:person('new-child').surname==surname)
-- Group recruitment: all members must be queued after ownership changes.
modules['familyTree/service']=service
local group={person('group-1'),person('group-2')}
for _,p in ipairs(group) do p.sharedState.tribeID='nomad' end
gom.callFunctionForAllSapiensInTribe=function(_,id,fn) for _,p in ipairs(group) do fn(p) end end
local sapiens={createChildFromMother=function() end,updateStatusForFriendsOfDyingSapien=function() end,
    removeSapien=function() end,recruitComplete=function() for _,p in ipairs(group) do p.sharedState.tribeID='tribe' end end}
dofile(ROOT..'/FamilyTree/scripts/server/serverSapien.lua'):onload(sapiens)
sapiens:recruitComplete(group[1],'tribe'); service:drain()
assert(group[1].sharedState.familyTreeSurname and group[2].sharedState.familyTreeSurname)
print('PASS surnames: paternal line, child-first loading, dead/absent father, maternal fallback, founder, reload, re-entry, rename, cycle, player-only mutation, legacy archive, birth override, group recruitment')
-- Settings persist per tribe and only accept validated data.
world.tribeIDForClientID=function(_,id) if id=='player' then return 'tribe' elseif id=='other' then return 'other' end end
local defaults=service:request('player',{action='getNameSettings'}).settings
assert(defaults.automatic and defaults.cultures.roman and defaults.cultures.greek)
assert(service:request('outsider',{action='setNameSettings',settings=defaults}).error)
assert(service:request('player',{action='setNameSettings',settings={automatic=true,culture='custom',customNames={}}}).error)
local custom={automatic=true,culture='custom',customNames={' My House ','My House','Other'}}
assert(#service:request('player',{action='setNameSettings',settings=custom}).settings.customNames==2)
service:init(world,gom)
assert(service:request('player',{action='getNameSettings'}).settings.cultures.custom)
local otherDefaults=service:request('other',{action='getNameSettings'}).settings
assert(not otherDefaults.automatic and next(otherDefaults.cultures)==nil)
custom.customNames={'My House'}
service:request('player',{action='setNameSettings',settings=custom})
local customPerson=person('customPerson'); service:observe(customPerson)
assert(customPerson.sharedState.name=='customPerson My House')
custom.automatic=false
service:request('player',{action='setNameSettings',settings=custom})
local disabledChild=person('disabledChild','customPerson'); service:observe(disabledChild)
assert(disabledChild.sharedState.name=='disabledChild')
service:observe(customPerson); assert(customPerson.sharedState.name=='customPerson My House')
-- Manual change before father is observed, inheritance, and migration from v0.4.
customPerson.sharedState.name='Marcus New House'
custom.automatic=true
service:request('player',{action='setNameSettings',settings=custom})
local heir=person('heir','customPerson'); service:observe(heir)
assert(customPerson.sharedState.name=='Marcus New House')
assert(heir.sharedState.name=='heir New House')
service:observe(customPerson); assert(customPerson.sharedState.name=='Marcus New House')
local legacy=person('legacy')
legacy.sharedState.familyTreeGivenName='Old'; legacy.sharedState.familyTreeSurname='Julius'
legacy.sharedState.name='New Cornelius'
service:observe(legacy); assert(legacy.sharedState.name=='New Cornelius')
-- Actual rename hook must ignore buildings and denied ownership, and protect unnamed sapiens.
modules['common/gameObject']={types={sapien={index=1}}}
gom.getObjectIfLoadedAndHasOwnershipPermissions=function(_,client,id) if client=='player' then return objects[id] end end
gom.changeObjectNameIfAllowed=function(self,client,id,name)
    local obj=self:getObjectIfLoadedAndHasOwnershipPermissions(client,id)
    if obj then obj.sharedState:set('name',name) end
end
dofile(ROOT..'/FamilyTree/scripts/server/serverGOM.lua'):onload(gom)
local named=person('named'); named.objectTypeIndex=1
gom:changeObjectNameIfAllowed('player','named','Titus Customus')
service:observe(named); assert(named.sharedState.name=='Titus Customus' and named.sharedState.familyTreeManualName)
gom:changeObjectNameIfAllowed('outsider','named','Denied'); assert(named.sharedState.name=='Titus Customus')
local building=person('building'); building.objectTypeIndex=2
gom:changeObjectNameIfAllowed('player','building','My House'); assert(not building.sharedState.familyTreeManualName)
for i=1,100 do
    local roman=Names:generate(tostring(i),{culture='roman'})
    local greek=Names:generate(tostring(i),{culture='greek'})
    assert(roman~=greek)
end
local many={}; for i=1,129 do many[i]='Name'..i end
assert(not modules['familyTree/nameSettings']:validate({automatic=true,culture='custom',customNames=many}))
print('PASS settings: validation, per-tribe persistence, off switch, custom list, manual rename hook, ownership, legacy migration, renamed paternal inheritance')
local model=modules['familyTree/nameSettings']
local matCfg=assert(model:validate({automatic=true,inheritance='maternal',cultures={roman=true},customNames={}}))
assert(model:defaults().inheritance=='paternal')
assert(not model:validate({automatic=true,inheritance='both',cultures={roman=true},customNames={}}))
local matMother=person('mat-mother'); matMother.sharedState.name='Mother Materna'
Names:manual(matMother,a,gom)
local matFather=person('mat-father'); matFather.sharedState.name='Father Paternus'
Names:manual(matFather,a,gom)
local matChild=person('mat-child','mat-father','mat-mother')
assert(Names:apply(matChild,a,gom,types,matCfg)=='Materna')
assert(a:person('mat-child').surnameParent=='mat-mother')
assert(modules['familyTree/familyStats']:lineage('mat-child',a)==modules['familyTree/familyStats']:lineage('mat-mother',a))
assert(Names:apply(matChild,a,gom,types,{automatic=true,inheritance='paternal'})=='Materna')
assert(Names:apply(person('mat-fallback','mat-father'),a,gom,types,matCfg)=='Paternus')
objects['mat-mother']=nil
a:observe({id='mat-mother',surname='Materna',status='deceased',deathTime=123})
assert(Names:apply(person('mat-orphan','mat-father','mat-mother'),a,gom,types,matCfg)=='Materna')
service:request('player',{action='setNameSettings',settings=matCfg})
service:init(world,gom)
assert(service:request('player',{action='getNameSettings'}).settings.inheritance=='maternal')
for _,key in ipairs({'sumerian','aztec'}) do
    for _,name in ipairs(CATALOG.names[key]) do assert(name:match('^[A-Za-z]+$'),'single-word names only: '..name) end
end
local oldExclusion=assert(model:validate({automatic=true,cultures={aztec=true,sumerian=true},customNames={},excludedNames={['Ur-Nammu']=true,['Cuauh-Calli']=true}}))
assert(oldExclusion.excludedNames[CATALOG.renamedNames['Ur-Nammu']])
assert(oldExclusion.excludedNames[CATALOG.renamedNames['Cuauh-Calli']])
local newExclusion=assert(model:validate(oldExclusion))
assert(newExclusion.excludedNames[CATALOG.renamedNames['Ur-Nammu']],'migration remains stable on reload')
for _,key in ipairs(CATALOG.order) do
    if key~='custom' then
        assert(#CATALOG.names[key]==128,key..' must have 128 names')
        local unique={}
        for _,name in ipairs(CATALOG.names[key]) do assert(not unique[name],key..' duplicate '..name); unique[name]=true end
        local cfg=assert(model:validate({automatic=true,cultures={[key]=true},customNames={}}))
        local members={}; for _,name in ipairs(CATALOG.names[key]) do members[name]=true end
        for i=1,100 do assert(members[Names:generate(tostring(i),cfg)],key) end
    end
end
local excluded={}; for _,name in ipairs(CATALOG.names.japanese) do excluded[name]=true end
excluded.Sato=nil
local cfg=assert(model:validate({automatic=true,cultures={japanese=true},customNames={},excludedNames=excluded}))
for i=1,100 do assert(Names:generate(tostring(i),cfg)=='Sato') end
excluded.Sato=true
assert(not model:validate({automatic=true,cultures={japanese=true},customNames={},excludedNames=excluded}))
assert(model:validate({automatic=false,cultures={},customNames={}}))
local mix=assert(model:validate({automatic=true,cultures={japanese=true,english=true,custom=true},customNames={'Sato','OwnHouse'}}))
assert(#CATALOG:pool(mix)==257,'merge and deduplicate enabled pools')
service:request('player',{action='setNameSettings',settings=cfg})
service:init(world,gom)
local restored=service:request('player',{action='getNameSettings'}).settings
assert(restored.cultures.japanese and restored.excludedNames.Suzuki and not restored.excludedNames.Sato)
local newFounder=person('japanese-founder'); service:observe(newFounder)
assert(newFounder.sharedState.familyTreeSurname=='Sato')
service:observe(named); assert(named.sharedState.name=='Titus Customus')
local inherited=person('inherited-disabled-pool','named'); service:observe(inherited)
assert(inherited.sharedState.familyTreeSurname=='Customus','selection never changes inherited names')
for _,legacy in ipairs({'mixed','roman','greek','custom'}) do
    local migrated=assert(model:validate({automatic=true,culture=legacy,customNames={'Legacy'}}))
    assert(migrated.cultures[legacy=='mixed' and 'roman' or legacy])
end
print('PASS cultural pools: twelve cultures with 128 unique names each, combined/custom pools, individual exclusions, no empty active pool, migration, persistence, stable manual and inherited names')
