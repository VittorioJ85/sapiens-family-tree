local stats = {}
-- Derive a lineage from known parent edges, not a non-unique surname alone.
function stats:lineage(id, archive)
    local seen, path = {}, {}
    local current = id
    for _ = 1, 256 do
        if seen[current] then
            local seed = current
            for i = seen[current], #path do if path[i] < seed then seed = path[i] end end
            return seed
        end
        seen[current] = #path + 1; path[#path + 1] = current
        local row = archive:person(current)
        if not row then return current end
        if row.surnameGroup then
            local group = archive:get("recruitGroup:" .. row.surnameGroup)
            if group and group.surname == row.surname then return "group:" .. row.surnameGroup end
        end
        local parent = row.surnameParent
        if parent==nil then parent=row.father or row.mother end
        if not parent then return current end
        local above = archive:person(parent)
        if above and above.surname and row.surname and above.surname ~= row.surname then return current end
        current = parent
    end
    return nil -- unresolved, never silently merge truncated lineages
end
local function countMember(result, memberID, tribe, archive, gom, constants)
    local row = archive:person(memberID)
    local live = gom:getObjectWithID(memberID)
    if row and row.deathTime ~= nil then result.deceased = result.deceased + 1
    elseif live and live.sharedState.tribeID == tribe then
        result.living = result.living + 1
        local age = constants:getAgeValue(live.sharedState)
        if not result.oldest or age > result.oldest.age or (age == result.oldest.age and memberID < result.oldest.id) then
            result.oldest = {id=memberID, name=live.sharedState.name, tribeID=tribe, age=age}
        end
    else result.unknown = result.unknown + 1 end
end
function stats:page(id, tribe, page, archive, gom, constants)
    local lineage = self:lineage(id, archive)
    local ids, count = archive:list('tribe:' .. tribe, page)
    local result = {living=0, deceased=0, unknown=0, page=page, done=(page+1)*archive.pageSize >= count, resolved=lineage ~= nil}
    for _, memberID in ipairs(ids) do
        if lineage and self:lineage(memberID, archive) == lineage then
            countMember(result,memberID,tribe,archive,gom,constants)
        end
    end
    return result
end
-- Build a transient lineage index only on demand, one archive page per request.
-- Reopening/refocusing then reads only the selected family's members. Do not
-- cache live/dead counts or ages: loaded membership and ages can change without
-- an archive write. A revision change rejects mixed-generation pagination.
function stats:summary(id, tribe, page, archive, gom, constants, revision)
    local current = archive.revision or 0
    if revision ~= nil and revision ~= current then
        return {error="Family records changed. Refresh to recount."}
    end
    archive.statsIndexes = archive.statsIndexes or {}
    archive.statsIndexOrder = archive.statsIndexOrder or {}
    local index = archive.statsIndexes[tribe]
    if not index then
        if #archive.statsIndexOrder >= 4 then
            archive.statsIndexes[table.remove(archive.statsIndexOrder,1)] = nil
        end
        archive.statsIndexOrder[#archive.statsIndexOrder+1] = tribe
    end
    if not index or index.revision ~= current then
        index = {revision=current,page=0,lineages={},groups={}}
        archive.statsIndexes[tribe] = index
    end
    if not index.ready then
        local ids,count = archive:list('tribe:'..tribe,index.page)
        for _,memberID in ipairs(ids) do
            if index.lineages[memberID] == nil then
                local lineage = self:lineage(memberID,archive)
                index.lineages[memberID] = lineage or false
                if lineage then
                    local group = index.groups[lineage] or {}
                    index.groups[lineage] = group
                    group[#group+1] = memberID
                end
            end
        end
        index.page = index.page + 1
        index.ready = index.page * archive.pageSize >= count
        if not index.ready then return {pending=true,revision=current} end
    end
    local lineage = index.lineages[id]
    local members = lineage and index.groups[lineage] or {}
    local result = {living=0,deceased=0,unknown=0,page=page,revision=current,
        done=(page+1)*archive.pageSize>=#members,resolved=not not lineage}
    for i=page*archive.pageSize+1,math.min(#members,(page+1)*archive.pageSize) do
        countMember(result,members[i],tribe,archive,gom,constants)
    end
    return result
end
return stats
