local Archive = dofile(ROOT .. "/FamilyTree/scripts/familyTree/archive.lua")
local function clone(value)
    if type(value) ~= "table" then return value end
    local t = {}; for k, v in pairs(value) do t[k] = clone(v) end; return t
end
local function database()
    return {data = {}, reads = 0, writes = 0,
        dataForKey = function(self, key) self.reads = self.reads + 1; return clone(self.data[key]) end,
        setDataForKey = function(self, value, key) self.writes = self.writes + 1; self.data[key] = clone(value) end}
end
local db = database()
local a = Archive.new(db)
a:observe({id = "gm", name = "Grandmother", tribeID = "t"})
a:observe({id = "m", mother = "gm", tribeID = "t"})
a:observe({id = "f", tribeID = "t"})
a:observe({id = "x", mother = "m", father = "f", tribeID = "t"})
a:observe({id = "y", mother = "m", father = "f", tribeID = "t"})
a:observe({id = "z", mother = "m", father = "other", tribeID = "t"})
a:observe({id = "u", mother = "m", tribeID = "t"})
local sibs = a:siblings("x", 0)
assert(#sibs == 3)
assert(sibs[1].relationship == "Sibling")
assert(sibs[2].relationship == "Half-sibling")
assert(sibs[3].relationship == "Sibling (other parent unknown)")
assert(a:family("x", 0).ancestors.MM.name == "Grandmother")
local writes = db.writes
a:observe({id = "x", mother = "m", father = "f", tribeID = "t"})
assert(db.writes == writes, "unchanged observations must not write")
a:observe({id = "x", deathTime = 100, status = "deceased", ageAtDeath = 40})
a:observe({id = "x", status = "removed"})
a:observe({id = "x", status = "lastSeenAlive"})
assert(a:person("x").status == "deceased")
a:observe({id = "m", mother = "x"})
assert(a:family("x", 0).cycle)
local countBefore = select(2, a:list("tribe:t", 0))
a:observe({id = "x", tribeID = "t2"})
assert(a:hasMember("t", "x") and a:hasMember("t2", "x"))
assert(select(2, a:list("tribe:t", 0)) == countBefore)
local b = Archive.new(db)
assert(b:person("x").deathTime == 100)
assert(b:family("x", 0).ancestors.M.id == "m")
local nreads = db.reads
Archive.new(db)
assert(db.reads - nreads == 2, "startup reads only schema and one recovery journal, never enumerates archive")
local row = b:person("x"); row.name = "MUTATED"
assert(b:person("x").name ~= "MUTATED", "cache must not expose mutable tables")
for i = 1, 100 do a:observe({id = "c" .. i, mother = "big", tribeID = "t"}) end
assert(a:family("big", 0) == nil) -- missing parent stays unrecorded
a:observe({id = "big", tribeID = "t"})
assert(#a:family("big", 0).children == 32)
assert(#a:family("big", 3).children == 4)
assert(a:family("big", 4).childCount == 100)
-- A corrected parent leaves only a harmless stale index candidate.
a:observe({id = "c1", mother = "newMother"})
assert(#a:family("big", 0).children == 31)
local serviceModules = {['familyTree/nameCatalog']=CATALOG,['familyTree/archive'] = Archive,
    ['familyTree/conception'] = {init=function()end,update=function()end},
    ['familyTree/nameSettings'] = dofile(ROOT .. '/FamilyTree/scripts/familyTree/nameSettings.lua'),
    ['familyTree/familyStats'] = dofile(ROOT .. '/FamilyTree/scripts/familyTree/familyStats.lua'),
    ['familyTree/surnames'] = dofile(ROOT .. '/FamilyTree/scripts/familyTree/surnames.lua'),
    ['common/sapienConstants'] = {familyRelationshipTypes = {mother = 1, father = 2, sibling = 3, biologicalChild = 4},
        getAgeValue = function() return 20 end}}
mjrequire = function(name) return assert(serviceModules[name], name) end
serviceModules['common/gameObject'] = {types={sapien={index=1}}}
serviceModules['familyTree/requests'] = dofile(ROOT .. '/FamilyTree/scripts/familyTree/requests.lua')
local service = dofile(ROOT .. "/FamilyTree/scripts/familyTree/service.lua")
local objects = {}
local world = {getDatabase = function() return db end, getWorldTime = function() return 250 end,
    tribeIDForClientID = function(_, client) return client == "owner" and "t" or nil end}
local gom = {getObjectWithID = function(_, id) return objects[id] end}
service:reset(); service:init(world, gom)
assert(service:request("outsider", {action="family", id = "m"}).error)
assert(service:request("owner", {action="family", id = "notArchived"}).error)
assert(service:request("owner", {action = "list", page = math.huge}).error)
local live = {objectTypeIndex=1,uniqueID = "live", sharedState = {name = "Live", tribeID = "t", isFemale = false},
    lazyPrivateState = {relationships = {m = {familyRelationshipType = 1}}}}
objects.live = live
for i = 1, 10 do service:enqueue(live) end
assert(service.tail == 1)
service:drain()
assert(service.archive:person("live").mother == "m")
service:died(live)
service:observe(live, {status = "removed"})
assert(service.archive:person("live").status == "deceased")
assert(service.archive:person("live").ageAtDeath == 25)
assert(service:request("owner", {action="family", id = "live"}).root.deathTime == 250)
local isolatedDB = database()
world.getDatabase = function() return isolatedDB end
service:reset(); service:init(world, gom)
assert(service.archive:person("live") == nil, "worlds must be isolated")
print("PASS: parents, grandparents, full/half/unknown siblings, cycles, pagination, corrections, cache, deaths, membership, authorization, queue, reload and world isolation")

-- Exercise the actual onload adapters and their vanilla call order.
serviceModules['familyTree/service'] = service
serviceModules['server/serverGOM'] = gom
local net = {}
serviceModules['server/server'] = {registerNetFunction = function(_, name, fn) net[name] = fn end}
world.setBridge = function(self)
    objects.bridgeLoad = {uniqueID='bridgeLoad',objectTypeIndex=1,sharedState={name='Bridge load',tribeID='t'}}
    self:sapienLoaded(objects.bridgeLoad)
end
world.sapienLoaded = function() end
world.update = function() end
dofile(ROOT .. "/FamilyTree/scripts/server/serverWorld.lua"):onload(world)
world:setBridge({})
assert(net.familyTreeRequest)
assert(service.queued.bridgeLoad, 'retain events from new-world bridge initialization')
world:update(1)
assert(service.archive:person('bridgeLoad'))
for i = 1, 9 do
    local id = "queued" .. i
    objects[id] = {objectTypeIndex=1,uniqueID=id, sharedState={tribeID="t", name=id}, lazyPrivateState={relationships={}}}
    world:sapienLoaded(objects[id])
end
world:update(1)
assert(service.archive:person("queued4") and not service.archive:person("queued5"))
world:update(1); world:update(1)
assert(service.archive:person("queued9"))
local mother = {objectTypeIndex=1,uniqueID="mother",sharedState={name="Mother",tribeID="t",isFemale=true,pregnancyFatherInfo={fatherID="absentFather"}},
    lazyPrivateState={relationships={}}}
objects.mother = mother
local sapiens = {
    createChildFromMother = function(_, m)
        m.sharedState.pregnancyFatherInfo = nil
        objects.newborn = {objectTypeIndex=1,uniqueID="newborn",sharedState={name="Child",tribeID="t"},lazyPrivateState={relationships={}}}
        return "newborn"
    end,
    updateStatusForFriendsOfDyingSapien = function() end,
    removeSapien = function(_, sapien) objects[sapien.uniqueID] = nil end,
    recruitComplete = function(_, sapien) sapien.sharedState.tribeID = "t" end,
}
dofile(ROOT .. "/FamilyTree/scripts/server/serverSapien.lua"):onload(sapiens)
assert(sapiens:createChildFromMother(mother) == "newborn")
assert(service.archive:person("newborn").father == "absentFather")
assert(service.archive:person("newborn").birthObservedTime == 250)
sapiens:updateStatusForFriendsOfDyingSapien(objects.newborn)
sapiens:removeSapien(objects.newborn)
assert(service.archive:person("newborn").status == "deceased")
sapiens:removeSapien(objects.queued1)
assert(service.archive:person("queued1").status == "removed")
print("PASS: vanilla adapter call order, four-observation update budget, captured absent father, birth time, death before removal, nonfatal removal")

for _, n in ipairs({5000, 50000}) do
    collectgarbage("collect")
    local largeDB = database()
    local large = Archive.new(largeDB)
    local start = os.clock()
    for i = 1, n do
        large:observe({id = tostring(i), name = "Sapien " .. i, tribeID = "tribe",
            mother = i > 2 and tostring(math.floor(i / 2)) or nil,
            father = i > 3 and tostring(math.floor(i / 2) - 1) or nil})
    end
    local build = os.clock() - start
    local reads = largeDB.reads
    start = os.clock()
    large = Archive.new(largeDB)
    local open = os.clock() - start
    assert(largeDB.reads - reads == 2, "constant schema + recovery journal reads")
    reads = largeDB.reads
    start = os.clock()
    for i = 1, 1000 do assert(large:family(tostring(n - 10), 0)) end
    local queries = os.clock() - start
    local cacheCount = 0; for _ in pairs(large.cache) do cacheCount = cacheCount + 1 end
    assert(cacheCount <= 256)
    print(string.format("BENCH n=%d build=%.4fs reopen=%.6fs 1000_queries=%.4fs db_reads=%d cache_entries=%d writes=%d (in-memory DB, not world load time)",
        n, build, open, queries, largeDB.reads - reads, cacheCount, largeDB.writes))
end
