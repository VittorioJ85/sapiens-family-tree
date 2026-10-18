-- All providers run before Hammerstone builds its patch catalog (loadOrder 0).
-- mjrequire shares the versioned support instance across enabled providers.
local mod = {loadOrder = -100}
function mod:onload(manager)
    (mjrequire "vittorioCompatibility/v1/state"):install(manager)
end
return mod
