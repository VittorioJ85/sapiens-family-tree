local mod={loadOrder=20}
function mod:onload(order)
    (mjrequire "common/typeMaps"):insert("order",order.types,{key="ftTryForBaby",name="Try for a Baby",
        inProgressName="Spending time together",icon="icon_sapiens"})
end
return mod
