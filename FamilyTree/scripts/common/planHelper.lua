local mod={loadOrder=20}
function mod:onload(helper)
    local available=helper.availablePlansForObjectInfos
    function helper:availablePlansForObjectInfos(base,selected,tribe,...)
        local original=available(self,base,selected,tribe,...)
        if not original or not selected or #selected~=1 then return original end
        local s=selected[1]
        local constants=mjrequire "common/sapienConstants"
        if s.objectTypeIndex~=(mjrequire "common/gameObject").types.sapien.index or not s.sharedState or
            s.sharedState.tribeID~=tribe or s.sharedState.lifeStageIndex<constants.lifeStages.adult.index or
            (mjrequire "familyTree/conceptionRules").age(constants,s.sharedState)<18 then return original end
        -- Copy: other menu adapters may reuse the native result table.
        local result={};for i,v in ipairs(original) do result[i]=v end
        result[#result+1]={planTypeIndex=(mjrequire "common/plan").types.ftTryForBaby.index,hasNonQueuedAvailable=true}
        return result
    end
end
return mod
