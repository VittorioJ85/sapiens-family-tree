local family = mjrequire "familyTree/ui"
local locale = mjrequire "common/locale"
local mod = {loadOrder = 20}
function mod:onload(panel)
    local inspectUI
    function panel:init(inspect, follower, world, container)
        inspectUI = inspect
        family:init(container)
    end
    function panel:show(sapien)
        inspectUI:setModalPanelTitleAndObject(sapien.sharedState.name .. " - " .. locale:get("sapien_ui_relationships"), sapien)
        family:show(sapien)
    end
    function panel:hide() family:hide() end
    -- Required by the vanilla collection; Family Tree owns its navigation history.
    function panel:setBackFunction(fn) end
end
return mod
