local service = mjrequire "familyTree/service"
local mod = {loadOrder = 20}
function mod:onload(sapiens)
    local sequence=sapiens.actionSequenceTypeIndexForOrder
    function sapiens:actionSequenceTypeIndexForOrder(sapien,object,state)
        if state.orderTypeIndex==(mjrequire "common/order").types.ftTryForBaby.index then
            return (mjrequire "common/actionSequence").types.ftTryForBaby.index
        end
        return sequence(self,sapien,object,state)
    end
    local create = sapiens.createChildFromMother
    function sapiens:createChildFromMother(mother, ...)
        local fatherID = mother.sharedState.pregnancyFatherInfo and mother.sharedState.pregnancyFatherInfo.fatherID
        local childID = create(self, mother, ...)
        if childID and service.archive then
            local birth = service.archive:get("pendingBirth:" .. mother.uniqueID)
            service:observe(mother)
            service:observe(service.gom:getObjectWithID(childID), {mother = mother.uniqueID,
                father = fatherID, birthTime = birth and birth.time,
                birthObservedTime = service.world:getWorldTime()})
            service.archive:put("pendingBirth:" .. mother.uniqueID, false)
        end
        return childID
    end
    local died = sapiens.updateStatusForFriendsOfDyingSapien
    function sapiens:updateStatusForFriendsOfDyingSapien(sapien, ...)
        service:died(sapien)
        return died(self, sapien, ...)
    end
    local remove = sapiens.removeSapien
    function sapiens:removeSapien(sapien, ...)
        service:observe(sapien, {status = "removed"})
        return remove(self, sapien, ...)
    end
    local recruit = sapiens.recruitComplete
    function sapiens:recruitComplete(sapien, ...)
        local sourceTribe = sapien.sharedState.tribeID
        local isNomad = sapien.sharedState.nomad
        local group = {}
        if service.gom and service.gom.callFunctionForAllSapiensInTribe then
            service.gom:callFunctionForAllSapiensInTribe(sapien.sharedState.tribeID, function(member)
                group[#group + 1] = member
            end)
        end
        recruit(self, sapien, ...)
        -- Only vanilla nomad recruitment transfers a whole spawned tribe. Do not
        -- infer families from proximity or from individually recruited settled NPCs.
        if isNomad and sourceTribe ~= sapien.sharedState.tribeID then
            service:recruitedGroup(group, sapien.sharedState.tribeID)
        end
        service:enqueue(sapien)
        for _, member in ipairs(group) do service:enqueue(member) end
    end
end
return mod
