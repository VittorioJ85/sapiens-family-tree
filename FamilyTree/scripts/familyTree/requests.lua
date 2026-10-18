-- Server boundary: validate client data before observing objects or writing settings.
-- Tribe ownership always comes from the authenticated game connection.
local nameSettings = mjrequire "familyTree/nameSettings"
local familyStats = mjrequire "familyTree/familyStats"
local constants = mjrequire "common/sapienConstants"
local requests = {}
local actions = {family=true, familyStats=true, familySummary=true, person=true, household=true, branch=true, list=true, getNameSettings=true, setNameSettings=true}
local CHILD_PAGE = 8
local fields = {action=true, id=true, page=true, relation=true, settings=true, revision=true}
local publicFields = {"id", "name", "tribeID", "status", "ageAtDeath", "deathTime", "relationship"}

local function validID(id)
    -- Colons delimit archive keys; neither delimiters nor control characters are IDs.
    return type(id) == "string" and #id > 0 and #id <= 128 and not id:find("[:%c%s]")
end

local function validate(request)
    if type(request) ~= "table" or not actions[request.action] then return nil end
    for key in pairs(request) do if not fields[key] then return nil end end
    local page = request.page == nil and 0 or request.page
    if type(page) ~= "number" or page ~= page or page < 0 or page > 1000000 or page ~= math.floor(page) then return nil end
    if request.revision ~= nil then
        local revision=request.revision
        if request.action~="familySummary" or type(revision)~="number" or revision~=revision or revision<0
            or revision>9007199254740991 or revision%1~=0 then return nil end
    end
    if request.action == "branch" then
        if request.relation ~= "parents" and request.relation ~= "children" then return nil end
        if request.relation == "parents" and page ~= 0 then return nil end
    elseif request.relation ~= nil and request.relation ~= "children" and request.relation ~= "siblings" then return nil end
    if request.action == "household" and (page ~= 0 or request.relation ~= nil) then return nil end
    if (request.action == "family" or request.action == "familyStats" or request.action == "familySummary" or request.action == "branch" or request.action == "person" or request.action == "household") and not validID(request.id) then return nil end
    return page
end

-- Explicit public shape prevents future archive fields from leaking over the network.
local function publicPerson(row)
    if row.status == "unknown" then return {status="unknown"} end
    local result = {}
    for _, field in ipairs(publicFields) do result[field] = row[field] end
    return result
end

-- Absolute world calendar (not tribe age or Sapien age). Older archives have
-- no birth event; the child-object observation must never masquerade as one.
local function calendarDate(world, time)
    if type(time) ~= "number" or time ~= time or time < 0 or time == math.huge then return nil end
    local day = world.getDayLength and world:getDayLength()
    local year = world.getYearLength and world:getYearLength()
    if not day or not year or day <= 0 or year <= 0 then return nil end
    local yearIndex = math.floor(time / year)
    return string.format("Year %d, Day %d", yearIndex + 1, math.floor((time - yearIndex * year) / day) + 1)
end

function requests:handle(service, clientID, request)
    local archive = service.archive
    if not archive then return {error="Archive not ready"} end
    local tribe = service.world:tribeIDForClientID(clientID)
    if not tribe then return {error="No player tribe"} end
    local function person(row)
        local item = publicPerson(row)
        if row.status ~= "unknown" then
            item.birthDate = calendarDate(service.world, row.birthTime)
            item.deathDate = calendarDate(service.world, row.deathTime)
            item.childDate = calendarDate(service.world, row.birthObservedTime)
            -- Use the same age as the native Sapien list, including its +5
            -- offset. Never infer age from world-calendar dates or expose live
            -- state of former members now belonging to another player's tribe.
            if row.deathTime == nil and row.status ~= "deceased" then
                local live = row.id and service.gom:getObjectWithID(row.id)
                local state = live and service:isSapien(live) and live.sharedState
                local stage = state and state.lifeStageIndex
                if state and state.tribeID == tribe and type(stage) == "number" and stage >= 1 and
                    stage % 1 == 0 and constants.lifeStages and constants.lifeStages[stage] and
                    type(state.ageFraction) == "number" then
                    local age = constants:getAgeValue(state)
                    if age == age and age >= 0 and age < math.huge then item.age = math.floor(age) + 5 end
                end
            end
        end
        return item
    end
    local page = validate(request)
    if page == nil then return {error="Invalid Family Tree request"} end

    if request.action == "getNameSettings" then
        return {settings=nameSettings:get(archive, tribe)}
    elseif request.action == "setNameSettings" then
        local value, err = nameSettings:validate(request.settings)
        if not value then return {error=err} end
        archive:put("nameSettings:" .. tribe, value)
        return {settings=value}
    elseif request.action == "list" then
        local ids, count = archive:list("tribe:" .. tribe, page)
        local rows = {}
        for _, id in ipairs(ids) do
            rows[#rows + 1] = person(archive:person(id) or {id=id})
        end
        return {rows=rows, count=count, page=page}
    end

    local live = service.gom:getObjectWithID(request.id)
    if live and not service:isSapien(live) then return {error="Select a Sapien"} end
    if live and live.sharedState.tribeID == tribe then service:observe(live) end
    -- Historical membership is intentional: deceased and former members stay accessible.
    local function visible(id) return archive:hasMember(tribe, id) end
    if not visible(request.id) then return {error="Person not archived for this tribe"} end
    if request.action == "familyStats" then
        return familyStats:page(request.id, tribe, page, archive, service.gom, constants)
    end
    if request.action == "familySummary" then
        return familyStats:summary(request.id,tribe,page,archive,service.gom,constants,request.revision)
    end
    if request.action == "person" then
        local row=archive:person(request.id)
        return row and {root=person(row)} or {error="Person not recorded yet"}
    end

    if request.action == "branch" or request.action == "household" then
        -- A branch is exactly one generation. Never call family() here: it
        -- would also fetch grandparents and children the player did not open.
        local root = archive:person(request.id)
        if not root then return {error="Person not recorded yet"} end
        local function parents()
            local rows={}
            for _, key in ipairs({"mother", "father"}) do
                local id = root[key]
                local row = id and visible(id) and archive:person(id) or nil
                local item = row and person(row) or {status="unknown"}
                item.relationship = key == "mother" and "Mother" or "Father"
                rows[#rows + 1] = item
            end
            return rows
        end
        local function children()
            local rows, nextPage = {}, nil
            -- Eight candidates per visual page; storage keeps its existing
            -- 32-entry pages. Sparse pages never trigger an unbounded scan.
            local first = page * CHILD_PAGE
            local ids, count = archive:list("children:" .. request.id, math.floor(first / archive.pageSize))
            local offset = first % archive.pageSize
            for i=offset+1,math.min(offset+CHILD_PAGE,#ids) do
                local id=ids[i]
                -- Filter corrected edges and private people, but keep candidate
                -- pagination bounded even when an entire page is filtered out.
                local row = visible(id) and archive:person(id) or nil
                if row and (row.mother == request.id or row.father == request.id) then
                    local item = person(row)
                    item.relationship = "Child"
                    item.parentRole = row.mother == request.id and "Mother" or "Father"
                    item.coParentRole = item.parentRole == "Mother" and "Father" or "Mother"
                    local otherID = item.parentRole == "Mother" and row.father or row.mother
                    -- One additional direct parent per child, never a recursive
                    -- fetch. Inaccessible parents remain anonymous, including IDs.
                    local other = otherID and visible(otherID) and archive:person(otherID)
                    if other then
                        item.coParentID, item.coParentName = other.id, other.name
                        if request.action == "household" then
                            item.coParent = person(other)
                            item.coParent.relationship = item.coParentRole
                        end
                    end
                    rows[#rows + 1] = item
                end
            end
            if first + CHILD_PAGE < count then nextPage = page + 1 end
            return {rows=rows, nextPage=nextPage}
        end
        if request.action == "household" then
            local result=children()
            return {root=person(root),parents=parents(),children=result.rows,nextPage=result.nextPage}
        end
        return request.relation == "parents" and {rows=parents()} or children()
    end

    local data = archive:family(request.id, page, visible)
    if not data then return {error="Person not recorded yet"} end
    if request.relation == "siblings" then
        data.children, data.childCount = archive:siblings(request.id, page)
        data.siblings = true
    end
    data.root = person(data.root)
    for path, row in pairs(data.ancestors) do data.ancestors[path] = person(row) end
    local children = {}
    for _, row in ipairs(data.children) do
        if visible(row.id) then children[#children + 1] = person(row) end
    end
    data.children = children
    return data
end
return requests
