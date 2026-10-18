-- Security regressions use real mod modules and an isolated in-memory world.
local Archive = dofile(ROOT .. '/FamilyTree/scripts/familyTree/archive.lua')
local values, writes = {}, 0
local database = {
    dataForKey = function(_, key) return values[key] end,
    setDataForKey = function(_, value, key) values[key] = value; writes = writes + 1 end,
}
local modules = {
    ['familyTree/archive'] = Archive,
    ['familyTree/nameCatalog'] = CATALOG,
    ['common/gameObject'] = {types={sapien={index=1}}},
    ['common/sapienConstants'] = {familyRelationshipTypes={mother=1,father=2,biologicalChild=4}},
}
mjrequire = function(name) return assert(modules[name], name) end
for _, name in ipairs({'nameSettings', 'surnames', 'familyStats'}) do
    modules['familyTree/' .. name] = dofile(ROOT .. '/FamilyTree/scripts/familyTree/' .. name .. '.lua')
end
modules['familyTree/requests'] = dofile(ROOT .. '/FamilyTree/scripts/familyTree/requests.lua')
local service = dofile(ROOT .. '/FamilyTree/scripts/familyTree/service.lua')
local objects = {}
local gom = {getObjectWithID=function(_, id) return objects[id] end, saveObject=function() end}
local world = {
    getDatabase=function() return database end,
    tribeIDForClientID=function(_, client) return client == 'owner' and 't' or nil end,
    clientIDForTribeID=function() return 'owner' end,
}
mj = {serverClientID='server'}
service:init(world, gom)
local a = service.archive
local function request(data) return service:request('owner', data) end
local function person(id, objectType)
    local state = {name=id,tribeID='t'}
    function state:set(key, value) self[key] = value end
    objects[id] = {uniqueID=id,sharedState=state,objectTypeIndex=objectType or 1,lazyPrivateState={relationships={}}}
    return objects[id]
end
local settings = {automatic=true,cultures={roman=true},customNames={}}
assert(request({action='setNameSettings',settings=settings}).settings)

local building = person('building', 2)
assert(request({action='family',id='building'}).error, 'RPC must not archive non-Sapien objects')
assert(building.sharedState.name=='building' and not a:person('building'))

a:observe({id='outside',tribeID='enemy',mother='secret',name='Private',surname='Hidden',surnameParent='secret'})
a:observe({id='secret',tribeID='enemy',name='Secret'})
a:observe({id='child',tribeID='t',mother='outside',name='Child'})
local response = request({action='family',id='child'})
assert(response.ancestors.M.status=='unknown')
assert(not response.ancestors.M.id and not response.ancestors.M.mother and not response.ancestors.M.surnameParent)
assert(not response.ancestors.MM, 'never traverse beyond an unauthorized ancestor')
assert(not response.root.mother, 'public DTO must not contain internal ancestry edges')
local counts = request({action='familyStats',id='child'})
assert(counts.resolved and not counts.lineage, 'do not return a private lineage ID')
local summary=request({action='familySummary',id='child'})
assert(summary.resolved and not summary.lineage and not summary.groups and not summary.lineages)
assert(request({action='familySummary',id='outside'}).error)
assert(request({action='familySummary',id='building'}).error)
assert(service:request('outsider',{action='familySummary',id='child'}).error)
for _,revision in ipairs({-1,0.5,0/0,math.huge,'0',{},false})do
    assert(request({action='familySummary',id='child',revision=revision}).error)
end
assert(request({action='family',id='child',revision=0}).error)
assert(request({action='familySummary',id='a:b'}).error)

local untouched = person('untouched')
for _, bad in ipairs({false, 'invalid', {action='unknown',id='untouched'}, {action='family',id={}},
    {action='family',id='untouched',relation='unknown'}, {action='family',id='a:b'},
    {action='list',page={}}, {action='list',page=false}, {action='list',page=-1},
    {action='list',page=0.5}, {action='list',page=0/0}, {action='list',page=math.huge}}) do
    assert(request(bad).error, 'malformed request must be rejected')
end
assert(not a:person('untouched') and untouched.sharedState.name=='untouched')
assert(service:request('outsider',{action='getNameSettings'}).error)

local model = modules['familyTree/nameSettings']
for _, custom in ipairs({{[2]='Gap'}, {extra='hidden'}, {[129]='Overflow'}, {[0]='Zero'}}) do
    assert(not model:validate({automatic=false,cultures={},customNames=custom}), 'reject non-list custom names')
end
local excluded = {}; for i=1,5000 do excluded['bad'..i]=true end
assert(not model:validate({automatic=false,cultures={},customNames={},excludedNames=excluded}))
assert(not model:validate({automatic=false,cultures={},customNames={'bad\0name'}}))
assert(not model:validate({automatic=false,cultures={},customNames={string.rep('a',97)}}))
for _, invalid in ipairs({string.char(255),string.char(192,128),string.char(237,160,128),
    string.char(244,144,128,128),string.char(226,130)}) do
    assert(not model:validateCustomNames({invalid}), 'reject invalid UTF-8')
end
assert(model:validateCustomNames({'Müller','Évrard','佐藤'}), 'retain valid UTF-8 names')
local giant={}; for i=1,129 do giant[i]='Name'..i end
assert(not request({action='setNameSettings',settings={automatic=false,cultures={},customNames=giant}}).settings)
assert(request({action='getNameSettings'}).settings.automatic, 'rejected updates must not overwrite saved settings')

-- Neither the DB adapter nor callers may retain references to nested cache data.
local draft = {cultures={roman=true},customNames={'Alpha'}}
a:put('isolation',draft); draft.cultures.roman=false
local fetched=a:get('isolation'); assert(fetched.cultures.roman)
fetched.cultures.roman=false; fetched.customNames[1]='Mutated'
assert(a:get('isolation').cultures.roman and a:get('isolation').customNames[1]=='Alpha')
assert(values.isolation.cultures.roman and values.isolation.customNames[1]=='Alpha')

-- Reinitialization must clear queued IDs from the previous world.
service:enqueue(untouched); service:init(world,gom)
assert(service.tail==0 and next(service.queued)==nil)
service:reset(); assert(not service.world and not service.gom and not service.archive)
print('PASS audit: object types, RPC validation, privacy, bounded settings, nested cache isolation and lifecycle reset')
