-- Exact-source overlays affect only enabled, known mod files in this Lua VM.
-- No disk writes, new network callbacks, save migration or external commands.
local state={groups={},overlays={}}
local function normalize(text)
    if type(text)~="string" then return nil end
    return (text:gsub("^\239\187\191",""):gsub("\r\n","\n"))
end
local function pathKey(path)
    if type(path)~="string" then return nil end
    local result=path:gsub("\\","/"):gsub("/+","/")
    if package.config:sub(1,1)=="\\" then result=result:lower() end
    return result
end
local function log(id,status,detail)
    mj:log("Vittorio embedded compatibility v1: ",id," - ",status,detail and (" ("..detail..")") or "")
end
function state:install(manager)
    if self.installed then return end
    local active={}
    for kind,mods in pairs(manager.enabledModDirNamesAndVersionsByType or {}) do
        for _,entry in ipairs(mods) do
            local info=manager.modInfosByTypeByDirName[kind][entry.name]
            if info then active[info.name]={path=entry.path,version=tostring(entry.version)} end
        end
    end
    -- Choose an enabled, self-contained provider. Never require another mod.
    local own
    for _,name in ipairs({"Family Tree", "Rites and Remembrance", "Structures Plus", "Precise Rotation"}) do
        local candidate=active[name]
        if candidate and fileUtils.getFileContents(candidate.path.."/compatibility/vittorio-v1/manifest.json") then
            own=candidate
            break
        end
    end
    if not own then return end
    self.installed=true
    self.reader=fileUtils.getFileContents
    local function read(path) return normalize(self.reader(path)) end
    local function asset(path) return read(own.path.."/"..path) end
    local scripts=fileUtils.getResourcePath("scripts")
    for _,group in ipairs(mjrequire "vittorioCompatibility/v1/catalog") do
        local target=active[group.name]
        local report={status="not installed"}
        self.groups[group.id]=report
        if target then
            local pending={}
            local reason
            local changed=false
            if target.version~=group.version then reason="unrecognized mod version" end
            if not reason then
                for _,guard in ipairs(group.guards) do
                    local expected=asset(guard.expected)
                    local current=read(scripts.."/"..guard.path)
                    local recognized=expected and current==expected
                    for _,alternative in ipairs(guard.alternatives or {}) do
                        local source=asset(alternative)
                        if source and current==source then recognized=true end
                    end
                    if not recognized then
                        reason="unrecognized game source: "..guard.path;break
                    end
                end
            end
            if not reason then
                for _,file in ipairs(group.files) do
                    local path=target.path.."/"..file.path
                    local content=read(path)
                    local replacement=asset(file.replacement)
                    if not content or not replacement then reason="missing source or repair asset";break end
                    if content~=replacement then
                        local recognized=false
                        for _,before in ipairs(file.accepted) do
                            if content==asset(before) then recognized=true;break end
                        end
                        if not recognized then reason="unrecognized mod source: "..file.path;break end
                        changed=true
                        -- Hammerstone's patch anchors contain explicit CRLFs.
                        pending[pathKey(path)]={before=content,after=replacement:gsub("\n","\r\n")}
                    end
                end
            end
            if reason then report.status="skipped";report.reason=reason
            elseif not changed then report.status="already corrected"
            elseif group.kind=="ddapi" then report.status="pending runtime repair"
            else
                report.status="active"
                for key,value in pairs(pending) do self.overlays[key]=value end
            end
        end
        log(group.id,report.status,report.reason)
    end
    if active["Time Control Plus"] then
        log("time-control-plus","covered at Creative Mode server-import boundary",
            "calendar and speed settings are unchanged")
    end
    if next(self.overlays) then
        local original=self.reader
        fileUtils.getFileContents=function(path,...)
            local content=original(path,...)
            local entry=self.overlays[pathKey(path)]
            -- Recheck to avoid replacing a file modified after startup validation.
            if entry and normalize(content)==entry.before then return entry.after end
            return content
        end
    end
end
function state:repairDDAPI(ddapi)
    local report=self.groups["hammerstone-ddapi"]
    if not report or report.status~="pending runtime repair" then return end
    local values={}
    if debug and debug.getupvalue then
        for i=1,20 do
            local name,value=debug.getupvalue(ddapi.checkAndSortLoaders,i)
            if not name then break end
            values[name]=value
        end
    end
    if values.ddapiManager~=ddapi or type(values.entityManagers)~="table"
        or type(values.sortedObjectLoaders)~="table" or type(values.log)~="table" then
        report.status="skipped"
        report.reason="unrecognized DDAPI closure; original left intact"
    else
        (mjrequire "vittorioCompatibility/v1/ddapiRepair"):apply(ddapi,values.entityManagers,values.sortedObjectLoaders,values.log)
        report.status="active"
    end
    log("hammerstone-ddapi",report.status,report.reason)
end
return state
