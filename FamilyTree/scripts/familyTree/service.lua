local Archive = mjrequire "familyTree/archive"
local constants = mjrequire "common/sapienConstants"
local surnames = mjrequire "familyTree/surnames"
local gameObject = mjrequire "common/gameObject"
local requests = mjrequire "familyTree/requests"
local nameSettings = mjrequire "familyTree/nameSettings"
local service = {queue = {}, queued = {}, head = 1, tail = 0}
function service:reset()
    self.archive, self.world, self.gom = nil, nil, nil
    self.queue, self.queued, self.head, self.tail = {}, {}, 1, 0
end
function service:init(world, gom)
    self:reset()
    self.world, self.gom = world, gom
    self.archive = Archive.new(world:getDatabase("familyTree_v1", true))
end
function service:isSapien(object)
    return object and object.objectTypeIndex == gameObject.types.sapien.index and object.sharedState ~= nil
end
function service:enqueue(sapien)
    if not self:isSapien(sapien) or self.queued[sapien.uniqueID] then return end
    self.tail = self.tail + 1
    self.queue[self.tail] = sapien.uniqueID
    self.queued[sapien.uniqueID] = true
end
function service:recruitedGroup(group, tribe)
    if not self.archive then return end
    local owner = self.world:clientIDForTribeID(tribe)
    local settings = nameSettings:get(self.archive, tribe)
    if not owner or owner == mj.serverClientID or not settings.automatic then return end
    local joined = {}
    for _, member in ipairs(group) do
        if self:isSapien(member) and member.sharedState.tribeID == tribe then joined[#joined + 1] = member end
    end
    if #joined > 1 then surnames:registerGroup(joined, tribe, self.archive, self.gom) end
end
function service:observe(sapien, extra)
    if not self.archive or not self:isSapien(sapien) then return end
    local state = sapien.sharedState
    local info = {id = sapien.uniqueID, name = state.name, tribeID = state.tribeID,
        isFemale = state.isFemale, status = "lastSeenAlive"}
    local rels = sapien.lazyPrivateState and sapien.lazyPrivateState.relationships or {}
    local types = constants.familyRelationshipTypes
    for id, rel in pairs(rels) do
        if rel.familyRelationshipType == types.mother then info.mother = id end
        if rel.familyRelationshipType == types.father then info.father = id end
    end
    for k, v in pairs(extra or {}) do info[k] = v end
    self.archive:observe(info)
    local owner = state.tribeID and self.world.clientIDForTribeID and self.world:clientIDForTribeID(state.tribeID)
    if owner and owner ~= mj.serverClientID then
        local settings = nameSettings:get(self.archive, state.tribeID)
        local surname, given, pending = surnames:apply(sapien, self.archive, self.gom, types, settings)
        if surname then
            self.archive:observe({id = sapien.uniqueID, name = state.name, surname = surname, givenName = given})
        elseif pending then
            self:enqueue(sapien)
        end
    end
    -- Recover a child's known parent even if only the parent's reciprocal link survives.
    for id, rel in pairs(rels) do
        if rel.familyRelationshipType == types.biologicalChild then
            local child = {id = id}
            child[state.isFemale and "mother" or "father"] = sapien.uniqueID
            self.archive:observe(child)
        end
    end
end
function service:drain()
    if not self.archive then return end
    -- Fixed work budget, including retries while surname occupancy pages load.
    for _ = 1, 4 do
        if self.head > self.tail then break end
        local id = self.queue[self.head]
        self.queue[self.head] = nil
        self.queued[id] = nil
        self.head = self.head + 1
        self:observe(self.gom:getObjectWithID(id))
    end
    if self.head > self.tail then self.queue, self.head, self.tail = {}, 1, 0 end
end
function service:died(sapien)
    if not self.archive or not self:isSapien(sapien) then return end
    self:observe(sapien, {status = "deceased", deathTime = self.world:getWorldTime(),
        ageAtDeath = math.floor(constants:getAgeValue(sapien.sharedState)) + 5})
end
function service:request(clientID, request)
    return requests:handle(self, clientID, request)
end
return service
