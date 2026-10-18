local mod={loadOrder=20}
function mod:onload(action)
    local finish=action.animateOutForOptionSelected
    function action:animateOutForOptionSelected(...)
        local ui=mjrequire "familyTree/conceptionUI"
        if ui:isVisible() then return self:hide() end
        return finish(self,...)
    end
end
return mod
