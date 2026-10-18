local mod={loadOrder=20}
function mod:onload(sequences)
    local action=(mjrequire "common/action").types
    local maps=mjrequire "common/typeMaps"
    maps:insert("actionSequence",sequences.types,{key="ftTryForBaby",
        actions={action.moveTo.index,action.ftWaitForPartner.index,action.ftSpendTimeTogether.index},assignedTriggerIndex=2})
end
return mod
