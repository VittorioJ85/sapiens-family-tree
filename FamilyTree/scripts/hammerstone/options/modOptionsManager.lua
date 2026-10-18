local mod={loadOrder=20}
function mod:onload(manager)
    local reset=manager.resetModOptions
    function manager:resetModOptions(options)
        if options.configKey ~= "familyTree" then return reset(self,options) end
        -- Reset is a draft, applied with Save in the rebuilt custom panel.
        local ui=mjrequire "familyTree/settingsUI"
        ui.resetNext=true
        return {}
    end
end
return mod
