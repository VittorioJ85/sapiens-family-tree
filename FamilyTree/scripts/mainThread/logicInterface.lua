local mod={loadOrder=20}
function mod:onload(logic)
    local call=logic.callServerFunction
    function logic:callServerFunction(name,data,callback)
        if name=="addPlans" and type(data)=="table" and data.planTypeIndex==(mjrequire "common/plan").types.ftTryForBaby.index then
            local ids=data.objectOrVertIDs
            if type(ids)=="table" and #ids==1 and type(ids[1])=="string" and not data.baseVertID then
                (mjrequire "familyTree/conceptionUI"):open(ids[1])
            end
            return
        end
        return call(self,name,data,callback)
    end
end
return mod
