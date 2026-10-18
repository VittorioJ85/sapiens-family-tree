-- Engine-independent, write-through archive. No full database scans at startup.
local Archive = {}
Archive.__index = Archive
local PAGE = 32
Archive.pageSize = PAGE
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end
function Archive.new(db)
    local schema = db:dataForKey("schema")
    assert(schema == nil or schema == 1, "Unsupported Family Tree archive version")
    if not schema then db:setDataForKey(1, "schema") end
    local self = setmetatable({db = db, cache = {}, slots = {}, cursor = 0, revision = 0}, Archive)
    self.pending = db:dataForKey("pendingWrite") or nil
    self:recover()
    return self
end
-- A single server VM owns this archive. Store the complete bounded write intent
-- before any person/index change, then replay exact values before accepting new
-- observations. Requires atomic, ordered single-key writes from the native DB;
-- this is recovery from interrupted operations, not a claim of power-loss fsync.
function Archive:recover()
    local pending = self.pending
    if not pending then return end
    assert(type(pending) == "table" and pending.version == 1 and type(pending.writes) == "table"
        and #pending.writes >= 1 and #pending.writes <= 10, "Invalid Family Tree recovery journal")
    local entries = 0
    for key, op in pairs(pending.writes) do
        entries = entries + 1
        assert(type(key) == "number" and key >= 1 and key <= #pending.writes and key % 1 == 0
            and type(op) == "table" and type(op.key) == "string" and type(op.value) == "table"
            and (op.key:match("^p:") or op.key:match("^list:") or op.key:match("^count:") or op.key:match("^member:")),
            "Invalid Family Tree recovery entry")
    end
    assert(entries == #pending.writes, "Sparse Family Tree recovery journal")
    self.db:setDataForKey(copy(pending), "pendingWrite")
    for _, op in ipairs(pending.writes) do
        self.db:setDataForKey(copy(op.value), op.key)
        self:remember(op.key, op.value)
    end
    self.db:setDataForKey(false, "pendingWrite")
    self.pending = nil
    self.revision = self.revision + 1
    -- A failed write may have interrupted the incremental occupancy update.
    self.nameUsage = nil
end
function Archive:commit(writes)
    if #writes == 0 then return end
    self.pending = {version = 1, writes = copy(writes)}
    self:recover()
end
function Archive:get(key)
    self:recover() -- readers must not observe half-applied indexes after a caught write error
    if self.cache[key] == false then return nil end
    if self.cache[key] ~= nil then return copy(self.cache[key]) end
    local value = self.db:dataForKey(key)
    self:remember(key, value or false)
    return value and copy(value) or nil
end
function Archive:remember(key, value)
    if self.cache[key] == nil then
        self.cursor = self.cursor % 256 + 1
        local old = self.slots[self.cursor]
        if old then self.cache[old] = nil end
        self.slots[self.cursor] = key
    end
    self.cache[key] = value and copy(value) or false
end
function Archive:put(key, value)
    self:recover()
    -- Settings contain nested tables. Neither callers nor DB adapters own the cache.
    self.db:setDataForKey(copy(value), key)
    self:remember(key, value)
    if key:match("^p:") or key:match("^recruitGroup:") then self.revision = self.revision + 1 end
end
function Archive:person(id)
    return id and self:get("p:" .. id) or nil
end
function Archive:append(index, id, writes)
    if not writes then
        self:recover()
        local planned = {}
        self:append(index, id, planned)
        self:commit(planned)
        return
    end
    local function add(key, value) writes[#writes + 1] = {key=key, value=value} end
    -- Membership keys make replay idempotent, including after reopening a world.
    local memberKey = "member:" .. index .. ":" .. id
    if self:get(memberKey) then return end
    local meta = self:get("count:" .. index) or {n = 0}
    if meta.n > 0 then
        local tail = self:get("list:" .. index .. ":" .. math.floor((meta.n - 1) / PAGE)) or {}
        if tail[(meta.n - 1) % PAGE + 1] == id then
            add(memberKey, {present = true})
            return
        end
    end
    local pageKey = "list:" .. index .. ":" .. math.floor(meta.n / PAGE)
    local page = self:get(pageKey) or {}
    page[meta.n % PAGE + 1] = id
    add(pageKey, page)
    add("count:" .. index, {n = meta.n + 1})
    add(memberKey, {present = true})
end
function Archive:list(index, pageNumber)
    local page = math.max(0, math.floor(tonumber(pageNumber) or 0))
    local count = (self:get("count:" .. index) or {}).n or 0
    return self:get("list:" .. index .. ":" .. page) or {}, count
end
function Archive:observe(info)
    self:recover()
    assert(type(info.id) == "string")
    local existing = self:person(info.id)
    local old = existing or {id = info.id}
    local row = copy(old)
    for _, k in ipairs({"name", "givenName", "surname", "surnameParent", "surnameGroup", "tribeID", "isFemale", "mother", "father", "deathTime", "ageAtDeath", "birthTime", "birthObservedTime", "status"}) do
        if info[k] ~= nil then row[k] = info[k] end
    end
    -- Event dates are captured once; replay/load callbacks cannot move them.
    for _, k in ipairs({"birthTime", "birthObservedTime", "deathTime"}) do
        if old[k] ~= nil then row[k] = old[k] end
    end
    -- A late load/removal notification must never resurrect an archived person.
    if old.deathTime ~= nil then row.status = "deceased" end
    local changed = false
    for k, v in pairs(row) do if old[k] ~= v then changed = true end end
    local writes, indexes = {}, {}
    if changed or not existing then writes[#writes + 1] = {key="p:" .. info.id, value=row} end
    for _, k in ipairs({"mother", "father"}) do
        if row[k] and row[k] ~= info.id and not indexes[row[k]] then
            self:append("children:" .. row[k], info.id, writes)
            indexes[row[k]] = true
        end
    end
    if row.tribeID then self:append("tribe:" .. row.tribeID, info.id, writes) end
    -- Keep the warm occupancy map on successful commits; recovery after an
    -- interrupted commit discards it before the next observation instead.
    local usage = self.nameUsage
    self:commit(writes)
    self.nameUsage = usage
    if self.nameUsage then
        local current = self.nameUsage[row.tribeID]
        if current then self:updateNameUsage(current, row, row.tribeID) end
        if old.tribeID ~= row.tribeID then
            local previous = self.nameUsage[old.tribeID]
            if previous then self:updateNameUsage(previous, row, old.tribeID) end
        end
    end
    return row
end
function Archive:nameKey(name)
    if type(name)~="string" then return nil end
    local key=string.lower(name:match("^%s*(.-)%s*$"))
    if key~="" then return key end
end
function Archive:updateNameUsage(index,row,tribe)
    local before=index.byID[row.id]
    local after
    if row.tribeID==tribe and row.deathTime==nil and row.status~="deceased" and row.status~="removed" then
        after=self:nameKey(row.surname or (row.name or ""):match("^%S+%s+(.+)$"))
    end
    if before==after then return end
    if before then
        local remaining = (index.counts[before] or 0) - 1
        index.counts[before] = remaining > 0 and remaining or nil
    end
    if after then index.counts[after]=(index.counts[after] or 0)+1 end
    index.byID[row.id]=after or nil
end
-- Build only when new names are needed. At most one archive page per call;
-- callers retry through the normal bounded observation queue until complete.
function Archive:usedSurnames(tribe)
    self.nameUsage=self.nameUsage or {}
    local index=self.nameUsage[tribe]
    if not index then
        index={page=0,counts={},byID={}}
        self.nameUsage[tribe]=index
    end
    if not index.ready then
        local ids,count=self:list("tribe:"..tribe,index.page)
        for _,id in ipairs(ids) do
            local row=self:person(id)
            if row then self:updateNameUsage(index,row,tribe) end
        end
        index.page=index.page+1
        index.ready=index.page*PAGE>=count
    end
    if not index.ready then return nil end
    return copy(index.counts),index.byID
end
function Archive:hasMember(tribeID, id)
    return self:get("member:tribe:" .. tribeID .. ":" .. id) ~= nil
end
function Archive:family(id, childPage, canRead)
    -- At most seven ancestry positions, plus one 32-entry child page.
    local root = self:person(id)
    if not root then return nil end
    local result = {root = root, ancestors = {}, children = {}, childPage = childPage or 0}
    local function visit(parentID, path, seen, depth)
        if not parentID or depth > 2 then return end
        -- Do not follow private edges past an unknown/outside-tribe ancestor.
        if canRead and not canRead(parentID) then
            result.ancestors[path] = {status="unknown"}
            return
        end
        if seen[parentID] then result.cycle = true; return end
        local row = self:person(parentID) or {id = parentID, status = "unknown"}
        result.ancestors[path] = row
        local nextSeen = copy(seen)
        nextSeen[parentID] = true
        visit(row.mother, path .. "M", nextSeen, depth + 1)
        visit(row.father, path .. "F", nextSeen, depth + 1)
    end
    visit(root.mother, "M", {[id] = true}, 1)
    visit(root.father, "F", {[id] = true}, 1)
    local children, count = self:list("children:" .. id, childPage)
    result.childCount = count
    for _, childID in ipairs(children) do
        local row = self:person(childID)
        -- Ignore stale index edges after an explicit parent correction.
        if row and (row.mother == id or row.father == id) then table.insert(result.children, row) end
    end
    return result
end
function Archive:siblings(id, pageNumber)
    local root = self:person(id)
    if not root then return {}, 0 end
    local motherCount = root.mother and ((self:get("count:children:" .. root.mother) or {}).n or 0) or 0
    local fatherCount = root.father and ((self:get("count:children:" .. root.father) or {}).n or 0) or 0
    local result = {}
    local first = (pageNumber or 0) * PAGE
    for offset = first, math.min(first + PAGE - 1, motherCount + fatherCount - 1) do
        local fromMother = offset < motherCount
        local parentID = fromMother and root.mother or root.father
        local pos = fromMother and offset or offset - motherCount
        local ids = self:list("children:" .. parentID, math.floor(pos / PAGE))
        local row = self:person(ids[pos % PAGE + 1])
        if row and row.id ~= id and (row.mother == parentID or row.father == parentID)
            and (fromMother or not root.mother or row.mother ~= root.mother) then
            local sameMother = root.mother and row.mother == root.mother
            local sameFather = root.father and row.father == root.father
            row.relationship = "Sibling (other parent unknown)"
            if sameMother and sameFather then row.relationship = "Sibling"
            elseif (sameMother and root.father and row.father and root.father ~= row.father)
                or (sameFather and root.mother and row.mother and root.mother ~= row.mother) then
                row.relationship = "Half-sibling"
            end
            table.insert(result, row)
        end
    end
    -- Count refers to candidate slots, so pagination stays bounded without a global scan.
    return result, motherCount + fatherCount
end
return Archive
