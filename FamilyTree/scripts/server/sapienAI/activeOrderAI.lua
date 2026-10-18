local mod={loadOrder=20}
function mod:onload(ai)
    local actions=(mjrequire "common/action").types
    for _,name in ipairs({"ftWaitForPartner","ftSpendTimeTogether"}) do
        -- The server-owned rendezvous advances both participants together.
        ai.updateInfos[actions[name].index]={checkFrequency=math.huge,allowCompletionWithoutSkill=true}
    end
end
return mod
