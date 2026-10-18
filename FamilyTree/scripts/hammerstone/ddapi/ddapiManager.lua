-- DDAPI can be imported before modManager onload callbacks have finished.
local mod = {loadOrder = 100}
function mod:onload(ddapi)
    if ddapi.vittorioCompatibilityV1InitWrapped then return end
    ddapi.vittorioCompatibilityV1InitWrapped = true
    local original = ddapi.init
    function ddapi:init(manager, ...)
        local state = mjrequire "vittorioCompatibility/v1/state"
        state:install(manager)
        state:repairDDAPI(self)
        return original(self, manager, ...)
    end
end
return mod
