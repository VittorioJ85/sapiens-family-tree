-- Execute installed game definitions where mocks could hide an API mismatch.
local modules={['common/mjm']={},['common/randomNumberGenerator']={}}
mjrequire=function(name)return assert(modules[name],name)end
mj={enum=function(_,names)local t={};for i,name in ipairs(names)do t[name]=i;t[i]=name end;return t end,
    indexed=function(_,entries)
        local result={}
        for key,value in pairs(entries)do
            value.key=value.key or key;value.index=#result+1
            result[value.index]=value;result[value.key]=value
        end
        return result
    end,
    insertIndexed=function(_,entries,value)value.index=#entries+1;entries[value.index]=value;entries[value.key]=value end,
    concatTables=function(_,a,b)local t={};for _,v in ipairs(a)do t[#t+1]=v end;for _,v in ipairs(b)do t[#t+1]=v end;return t end,
    tostring=function(_,v)return tostring(v)end,error=function(_,message)error(message)end}
local native=dofile(GAME..'/GameResources/scripts/common/animations/sapienCommon.lua')
dofile(ROOT..'/FamilyTree/scripts/common/animations/sapienCommon.lua'):onload(native)
local info={};native:setup(info,1)
local poses=info.animations.ftSpendTimeTogether.keyframes
local duration=0
for _,frame in ipairs(poses)do
    assert(type(frame[1])=='number' and frame[1]>0 and not frame[3],'Pose-only native keyframes')
    duration=duration+frame[2]
end
assert(duration==12 and poses[1][1]==info.animations.stand.keyframes[1][1])

-- Report 352234 (0.6.1.3) has no crouchLow animation. The local public
-- directory may contain newer assets, so exercise that missing capability too.
for _,missing in ipairs({{'crouchLow'},{'crouchLow','sitFocus'}}) do
    local compatible=dofile(GAME..'/GameResources/scripts/common/animations/sapienCommon.lua')
    local original=compatible.setup
    function compatible:setup(data,...)
        original(self,data,...)
        for _,name in ipairs(missing)do data.animations[name]=nil end
    end
    dofile(ROOT..'/FamilyTree/scripts/common/animations/sapienCommon.lua'):onload(compatible)
    local data={};compatible:setup(data,1)
    local sequence=data.animations.ftSpendTimeTogether.keyframes
    local seconds=0
    for _,frame in ipairs(sequence)do
        assert(type(frame[1])=='number' and frame[1]>0 and not frame[3])
        seconds=seconds+frame[2]
    end
    assert(seconds==12)
    assert(sequence[2][1]==(data.animations.sitFocus or data.animations.stand).keyframes[1][1])
end

-- Register all four type maps as the actual adapters do, then exercise the
-- installed AI's standard-action update for each stationary custom action.
modules['common/typeMaps']={insert=function(_,_,entries,value)mj:insertIndexed(entries,value)end}
local action={types={moveTo={index=80}}}
modules['common/action']=action
dofile(ROOT..'/FamilyTree/scripts/common/action.lua'):onload(action)
local order={types=setmetatable({}, {__index=function(_,key)return {index=key}end})}
modules['common/order']=order
dofile(ROOT..'/FamilyTree/scripts/common/order.lua'):onload(order)
local sequences={types={}}
dofile(ROOT..'/FamilyTree/scripts/common/actionSequence.lua'):onload(sequences)
local plan={types={}}
modules['common/plan']=plan
dofile(ROOT..'/FamilyTree/scripts/common/plan.lua'):onload(plan)
assert(plan.types.ftTryForBaby.name=='Try for a Baby')
assert(sequences.types.ftTryForBaby.actions[2]==action.types.ftWaitForPartner.index)
local ai={updateInfos={}}
dofile(ROOT..'/FamilyTree/scripts/server/sapienAI/activeOrderAI.lua'):onload(ai)
local f=assert(io.open(GAME..'/GameResources/scripts/server/sapienAI/activeOrderAI.lua','rb'))
local source=f:read('*a');f:close()
local body=assert(source:match('(local function updateStandardAction.-)\nlocal function updateInspectAction'))
local chunk=assert(loadstring(body..'\nreturn updateStandardAction'))
setfenv(chunk,setmetatable({order=order,
    planManager={getPlanSateForConstructionObject=function()end},
    skillLearning={getTaughtSkillInfo=function()end}}, {__index=_G}))
local update=chunk()
local s={sharedState={tribeID='t'},privateState={actionStateTimer=0}}
for _,name in ipairs({'ftWaitForPartner','ftSpendTimeTogether'})do
    local result=update(s,{},1000,1,{sharedState={},objectTypeIndex=10},
        {orderTypeIndex=order.types.ftTryForBaby.index,context={}},ai.updateInfos[action.types[name].index])
    assert(not result.cancel and not result.completed,'Native AI must wait for the pair coordinator')
end

-- The radial helper must preserve unrelated plans, and exclude children,
-- outsiders, multiple selections, and non-Sapien objects.
modules['common/gameObject']={types={sapien={index=1}}}
modules['common/sapienConstants']={lifeStages={adult={index=2}},getAgeValue=function(_,state)return state.age end}
modules['familyTree/conceptionRules']=dofile(ROOT..'/FamilyTree/scripts/familyTree/conceptionRules.lua')
local base={{planTypeIndex='original'}}
local helper={availablePlansForObjectInfos=function()return base end}
dofile(ROOT..'/FamilyTree/scripts/common/planHelper.lua'):onload(helper)
local person={objectTypeIndex=1,sharedState={tribeID='t',lifeStageIndex=2,age=25}}
assert(#helper:availablePlansForObjectInfos(person,{person},'t')==2 and #base==1)
assert(helper:availablePlansForObjectInfos(person,{person},'other')==base)
assert(helper:availablePlansForObjectInfos(person,{person,person},'t')==base)
person.sharedState.age=11;assert(helper:availablePlansForObjectInfos(person,{person},'t')==base)
person.objectTypeIndex=2;assert(helper:availablePlansForObjectInfos(person,{person},'t')==base)
print('PASS conception native definitions: real skeleton poses and duration, type registrations, native stationary-action update and radial eligibility')
