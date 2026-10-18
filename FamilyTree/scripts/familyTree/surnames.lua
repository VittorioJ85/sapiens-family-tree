local catalog = mjrequire "familyTree/nameCatalog"
local surnames = {}
local function splitName(full)
    local given, surname = full:match("^(%S+)%s+(.+)$")
    return given or full, surname or ""
end
function surnames:generate(id, settings, archive, gom, tribe)
    local pool=catalog:pool(settings)
    if #pool==0 then return nil end
    local hash=0
    for i=1,#id do hash=(hash*131+string.byte(id,i))%2147483647 end
    local start=hash%#pool+1
    if archive and tribe then
        local used,byID=archive:usedSurnames(tribe)
        if not used then return nil, true end -- pending index; retry in the bounded queue
        -- Include current members even before their queued archive observation,
        -- and account for manual renames since the last observation.
        if gom.callFunctionForAllSapiensInTribe then
            gom:callFunctionForAllSapiensInTribe(tribe,function(person)
                local state=person.sharedState
                if state.tribeID~=tribe then return end
                local previous=byID[person.uniqueID]
                if previous then used[previous]=math.max(0,(used[previous] or 0)-1) end
                local name=state.familyTreeSurname
                local expected=state.familyTreeLastName
                if not expected and state.familyTreeGivenName and name then expected=state.familyTreeGivenName.." "..name end
                if not name or (expected and expected~=state.name) then
                    local _, actual = splitName(state.name or "")
                    name = actual
                end
                local key=archive:nameKey(name)
                if key then used[key]=(used[key] or 0)+1 end
            end)
        end
        for offset=0,#pool-1 do
            local name=pool[(start+offset-1)%#pool+1]
            if (used[archive:nameKey(name)] or 0)==0 then return name end
        end
    end
    return pool[start] -- duplicates only when the enabled pool is occupied
end
-- Record the player's exact full name, including deliberate surname removal.
function surnames:manual(sapien, archive, gom)
    local state = sapien.sharedState
    local full = state.name or ""
    local given, surname = splitName(full)
    for key,value in pairs({familyTreeManualName=true, familyTreeLastName=full,
        familyTreeGivenName=given, familyTreeSurname=surname}) do state:set(key,value) end
    gom:saveObject(sapien.uniqueID)
    if archive then archive:observe({id=sapien.uniqueID, name=full, givenName=given, surname=surname}) end
    return surname, given
end
function surnames:detectManual(sapien, archive, gom)
    local state = sapien.sharedState
    local expected = state.familyTreeLastName
    if not expected and state.familyTreeGivenName and state.familyTreeSurname then
        expected = state.familyTreeGivenName .. " " .. state.familyTreeSurname
    end
    if expected and state.name ~= expected then self:manual(sapien, archive, gom) end
end
function surnames:resolve(id, archive, gom, types, settings)
    local origin=gom:getObjectWithID(id)
    local tribe=origin and origin.sharedState.tribeID or (archive:person(id) or {}).tribeID
    local path, seen, parents = {}, {}, {}
    local current, surname, pending = id, nil, false
    while current do
        local row = archive:person(current) or {}
        local live = gom:getObjectWithID(current)
        local state = live and live.sharedState
        if live then self:detectManual(live, archive, gom); row = archive:person(current) or row end
        surname = (state and state.familyTreeSurname) or row.surname
        if surname then break end
        if row.surnameGroup then
            local grouped
            surname, pending, grouped = self:groupName(live or {uniqueID=current,sharedState={tribeID=row.tribeID}}, archive, gom, settings)
            if grouped then break end
        end
        if seen[current] then
            local seed = current
            for i = seen[current], #path do if path[i] < seed then seed = path[i] end end
            surname, pending = self:generate(seed, settings, archive, gom, tribe)
            break
        end
        if #path >= 256 then return nil end -- retry after ancestors are recorded; no frame-sized unbounded walk
        seen[current] = #path + 1
        path[#path + 1] = current
        local father, mother = row.father, row.mother
        local rels = live and live.lazyPrivateState and live.lazyPrivateState.relationships or {}
        for parentID, rel in pairs(rels) do
            if rel.familyRelationshipType == types.father then father = parentID end
            if rel.familyRelationshipType == types.mother then mother = parentID end
        end
        local parent
        if settings and settings.inheritance=="maternal" then parent=mother or father
        else parent=father or mother end
        parents[current]=parent or false
        if not parent then surname, pending = self:generate(current, settings, archive, gom, tribe); break end
        current = parent
    end
    if surname == "" then surname, pending = self:generate(id, settings, archive, gom, tribe) end
    if not surname then return nil, pending end
    for _, personID in ipairs(path) do
        local row = archive:person(personID) or {id = personID}
        row.surname = surname
        row.surnameParent = parents[personID]
        if row.name then
            row.givenName = row.givenName or row.name
            row.name = row.givenName .. " " .. surname
        end
        archive:observe(row)
    end
    return surname
end
-- A shared house is an explicit recruitment assumption, never a fabricated parent
-- edge. Persist it before queuing names so delayed scans and reloads keep the group.
function surnames:registerGroup(members, tribe, archive, gom)
    table.sort(members, function(a,b) return a.uniqueID < b.uniqueID end)
    local key = members[1].uniqueID .. ":" .. tribe
    local group = archive:get("recruitGroup:" .. key) or {tribe=tribe, seed=members[1].uniqueID}
    local existing, manual
    for _, member in ipairs(members) do
        self:detectManual(member, archive, gom)
        local name = member.sharedState.familyTreeSurname
        if name and name ~= "" then
            existing = existing or name
            if member.sharedState.familyTreeManualName then manual = manual or name end
        end
    end
    group.surname = group.surname or manual or existing
    archive:put("recruitGroup:" .. key, group)
    for _, member in ipairs(members) do
        archive:observe({id=member.uniqueID, tribeID=tribe, name=member.sharedState.name, surnameGroup=key})
    end
end

function surnames:groupName(sapien, archive, gom, settings)
    local row = archive:person(sapien.uniqueID)
    local key = row and row.surnameGroup
    if not key then return nil, false, false end
    local group = archive:get("recruitGroup:" .. key)
    if not group or group.tribe ~= sapien.sharedState.tribeID then return nil, false, false end
    local pending
    if not group.surname then
        group.surname, pending = self:generate(group.seed, settings, archive, gom, group.tribe)
        if group.surname then archive:put("recruitGroup:" .. key, group) end
    end
    return group.surname, pending, true
end

function surnames:apply(sapien, archive, gom, types, settings)
    local state = sapien.sharedState
    self:detectManual(sapien, archive, gom)
    if state.familyTreeManualName or (settings and not settings.automatic) then
        return state.familyTreeSurname, state.familyTreeGivenName
    end
    local surname, pending, grouped = self:groupName(sapien, archive, gom, settings)
    if not grouped then surname, pending = self:resolve(sapien.uniqueID, archive, gom, types, settings) end
    if not surname then return nil, nil, pending end
    local given = state.familyTreeGivenName or state.name
    if not given then return end
    local changed = false
    for key, value in pairs({familyTreeGivenName = given, familyTreeSurname = surname,
        familyTreeLastName = given .. " " .. surname, name = given .. " " .. surname}) do
        if state[key] ~= value then state:set(key, value); changed = true end
    end
    if changed then gom:saveObject(sapien.uniqueID) end
    if grouped then
        archive:observe({id=sapien.uniqueID, name=state.name, givenName=given, surname=surname})
    end
    return surname, given
end
return surnames
