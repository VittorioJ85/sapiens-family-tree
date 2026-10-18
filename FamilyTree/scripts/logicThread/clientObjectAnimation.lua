local mod={loadOrder=20}
function mod:onload(animation)
    local change=animation.changeAnimation
    function animation:changeAnimation(object,index,groupIndex,speed)
        local state=object.sharedState and object.sharedState.actionState
        if state and state.sequenceTypeIndex==(mjrequire "common/actionSequence").types.ftTryForBaby.index and state.progressIndex==3 then
            local group=(mjrequire "common/animationGroups").groups[groupIndex]
            local together=group and group.animations.ftSpendTimeTogether
            if together then index=together.index;speed=1 end
        end
        return change(self,object,index,groupIndex,speed)
    end
end
return mod
