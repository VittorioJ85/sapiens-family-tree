local catalog = mjrequire "familyTree/nameCatalog"
local settings = {maxCustomNames=128, maxNameBytes=96}

-- Catalog membership is immutable. Build it once, not for each observed Sapien.
local knownNames, maxExclusions = {}, settings.maxCustomNames
for _, pool in pairs(catalog.names) do
    for _, name in ipairs(pool) do
        if not knownNames[name] then knownNames[name] = true; maxExclusions = maxExclusions + 1 end
    end
end
for _ in pairs(catalog.renamedNames) do maxExclusions = maxExclusions + 1 end

-- LuaJIT has no standard utf8 library. Reject malformed sequences before rendering
-- client-supplied names; valid non-ASCII names are still supported.
local function validUTF8(text)
    local i = 1
    while i <= #text do
        local first = text:byte(i)
        local length = first < 128 and 1 or (first >= 194 and first <= 223 and 2)
            or (first >= 224 and first <= 239 and 3) or (first >= 240 and first <= 244 and 4)
        if not length or i + length - 1 > #text then return false end
        for j = i + 1, i + length - 1 do
            local byte = text:byte(j)
            if byte < 128 or byte > 191 then return false end
        end
        local second = text:byte(i + 1)
        if (first == 224 and second < 160) or (first == 237 and second >= 160)
            or (first == 240 and second < 144) or (first == 244 and second >= 144) then return false end
        i = i + length
    end
    return true
end

function settings:defaults()
    return {automatic=false, inheritance="paternal", cultures={}, customNames={}, excludedNames={}}
end

function settings:validateCustomNames(value)
    if type(value) ~= "table" then return nil, "Invalid name list" end
    -- ipairs alone silently ignores sparse arrays and string-keyed payloads.
    local count, last = 0, 0
    for index in pairs(value) do
        count = count + 1
        if count > self.maxCustomNames then return nil, "Maximum 128 custom names" end
        if type(index) ~= "number" or index < 1 or index > self.maxCustomNames or index ~= math.floor(index) then
            return nil, "Invalid name list"
        end
        last = math.max(last, index)
    end
    if last ~= count then return nil, "Invalid name list" end
    local names, seen = {}, {}
    for _, name in ipairs(value) do
        if type(name) ~= "string" or #name > self.maxNameBytes or name:find("[%c,;]") or not validUTF8(name) then
            return nil, "Names: valid UTF-8, maximum 96 bytes; no controls, commas or semicolons"
        end
        name = name:match("^%s*(.-)%s*$")
        if name ~= "" and not seen[name] then names[#names + 1], seen[name] = name, true end
    end
    return names
end

function settings:validate(value)
    if type(value) ~= "table" or type(value.automatic) ~= "boolean" then return nil, "Invalid settings" end
    local inheritance = value.inheritance == nil and "paternal" or value.inheritance
    if inheritance ~= "paternal" and inheritance ~= "maternal" then return nil, "Choose paternal or maternal inheritance" end
    if value.cultures ~= nil and type(value.cultures) ~= "table" then return nil, "Invalid culture selection" end
    -- Keep legacy single-choice migration: existing worlds still use these records.
    if not value.cultures and value.culture ~= "mixed" and not catalog.labels[value.culture] then return nil, "Choose name groups" end
    local cultures = {}
    for key, on in pairs(catalog:selection(value)) do
        if not catalog.labels[key] or type(on) ~= "boolean" then return nil, "Invalid culture selection" end
        if on then cultures[key] = true end
    end
    local names, err = self:validateCustomNames(value.customNames)
    if not names then return nil, err end
    if value.excludedNames ~= nil and type(value.excludedNames) ~= "table" then return nil, "Invalid name selection" end
    local custom = {}
    for _, name in ipairs(names) do custom[name] = true end
    local excluded, count = {}, 0
    for name, off in pairs(value.excludedNames or {}) do
        count = count + 1
        if count > maxExclusions or type(name) ~= "string" or #name > self.maxNameBytes or type(off) ~= "boolean" then
            return nil, "Invalid name selection"
        end
        if off and (knownNames[name] or custom[name]) then excluded[name] = true end
        local replacement = catalog.renamedNames[name]
        if off and replacement then excluded[replacement] = true end
    end
    local result = {automatic=value.automatic, inheritance=inheritance, cultures=cultures, customNames=names, excludedNames=excluded}
    if result.automatic and #catalog:pool(result) == 0 then
        return nil, "Select at least one available surname, or turn automatic names off"
    end
    return result
end

function settings:get(archive, tribeID)
    local value = archive:get("nameSettings:" .. tribeID)
    if not value then return self:defaults() end
    return self:validate(value) or self:defaults()
end
return settings
