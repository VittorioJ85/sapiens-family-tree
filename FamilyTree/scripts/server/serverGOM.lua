local mod={loadOrder=20}
function mod:onload(gom)
    local notify = gom.sendNotificationForObject
    function gom:sendNotificationForObject(object, notificationType, ...)
        local notification = mjrequire "common/notification"
        local service = mjrequire "familyTree/service"
        if notificationType == notification.types.babyBorn.index and service.archive and service:isSapien(object) then
            -- Babies have no person ID yet. Keep the actual birth event on the
            -- mother's pending record until the native child object is created.
            service.archive:put("pendingBirth:" .. object.uniqueID, {time=service.world:getWorldTime()})
        end
        return notify(self, object, notificationType, ...)
    end
    local original=gom.changeObjectNameIfAllowed
    function gom:changeObjectNameIfAllowed(clientID,objectID,newName)
        local object=self:getObjectIfLoadedAndHasOwnershipPermissions(clientID,objectID)
        original(self,clientID,objectID,newName)
        local gameObject=mjrequire "common/gameObject"
        if object and object.objectTypeIndex==gameObject.types.sapien.index and object.sharedState.name==newName then
            local service=mjrequire "familyTree/service"
            local surnames=mjrequire "familyTree/surnames"
            surnames:manual(object,service.archive,self)
            service:observe(object)
        end
    end
    local loaded=gom.gameObjectWasLoaded
    function gom:gameObjectWasLoaded(object,...)
        loaded(self,object,...)
        if object.sharedState and object.sharedState.ftPair then
            local service=mjrequire "familyTree/service"
            local conception=mjrequire "familyTree/conception"
            conception:cleanup(service,object)
        end
    end
end
return mod
