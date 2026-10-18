local mod={loadOrder=20}
function mod:onload(action)
    local maps=mjrequire "common/typeMaps"
    maps:insert("action",action.types,{key="ftWaitForPartner",name="Wait for Partner",inProgress="Waiting for partner",restNeedModifier=0})
    maps:insert("action",action.types,{key="ftSpendTimeTogether",name="Spend Time Together",inProgress="Spending time together",restNeedModifier=0})
end
return mod
