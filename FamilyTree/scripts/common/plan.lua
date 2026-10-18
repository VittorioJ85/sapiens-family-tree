local mod={loadOrder=20}
function mod:onload(plan)
    (mjrequire "common/typeMaps"):insert("plan",plan.types,{key="ftTryForBaby",name="Try for a Baby",icon="icon_sapiens"})
end
return mod
