local mod={loadOrder=20}
function mod:onload(manager)
    local add=manager.addPlans
    function manager:addPlans(tribe,request,...)
        -- This radial entry opens a picker, not a native plan. In multiplayer,
        -- only familyTreeConception may authorize and start the selected pair.
        if request and request.planTypeIndex==(mjrequire "common/plan").types.ftTryForBaby.index then return nil end
        return add(self,tribe,request,...)
    end
end
return mod
