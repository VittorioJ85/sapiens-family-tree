-- Isolated lifecycle tests: real rules, archive, and native age calculation;
-- world/AI transport is simulated, so no original save is opened or changed.
local modules, objects, saved = {}, {}, {}
mjrequire=function(name)return assert(modules[name],name)end
mj={mToP=function(_,v)return v end,indexed=function(_,entries)
    for i,v in ipairs(entries)do v.index=i;entries[v.key]=v end;return entries
end,enum=function(_,entries)local t={};for i,k in ipairs(entries)do t[k]=i;t[i]=k end;return t end}
modules['common/mjm']={vec3=function()end,length2=function(x)return x*x end}
modules['common/locale']={get=function(_,s)return s end}
local constants=dofile(GAME..'/GameResources/scripts/common/sapienConstants.lua')
modules['common/sapienConstants']=constants
local rules=dofile(ROOT..'/FamilyTree/scripts/familyTree/conceptionRules.lua')
modules['familyTree/conceptionRules']=rules
modules['common/gameObject']={types={sapien={index=1},[2]={isBed=true,isBuiltObject=true},[3]={isBed=true}}}
modules['common/order']={types={ftTryForBaby={index=101},fall={index=102},flee={index=103},fight={index=104}}}
modules['common/actionSequence']={types={ftTryForBaby={index=201}}}
modules['common/statusEffect']={cantDoMostWorkDueToEffects=function(_,t)return t.unwell end}
modules['common/mood']={types={loyalty={index=1},happySad={index=2}},levels={mildNegative=3},getMood=function(_,s)return s.sharedState.moods[1] end}
modules['common/desire']={levels={strong=4},getDesire=function(_,s)return s.sharedState.hungry and 4 or 1 end}
modules['common/need']={types={food={index=1}}}
local storage={foodCountsByTribeID={t=50}}
modules['server/serverStorageArea']=storage
local pop, growth, roll=20,true,0.99
modules['server/serverTribe']={tribeAllowsPopulationGrowth=function()return growth end,getPopulation=function()return pop end}
modules['common/gameConstants']={populationLimitPerTribeSoftCap=150,populationLimitGlobalSoftCap=300}
modules['server/serverWorldSettings']={get=function()end}
modules['common/randomNumberGenerator']={randomValue=function()return roll end}
modules['common/notification']={types={becamePregnant={index=17}}}
modules['common/pathFinding']={proximityTypes={reachable=1}}
modules['server/objects/serverSeat']={removeAnyNodeAssignmentForSapien=function()end}
local notifications,updates=0,0
modules['server/planManager']={updateProximityForAbilityChange=function(_,id)assert(id=='a');updates=updates+1 end}
local now=100
local function state(values)
    function values:set(key,value)self[key]=value end
    function values:remove(key)self[key]=nil end
    return values
end
local function person(id,female,tribe)
    local s={uniqueID=id,objectTypeIndex=1,pos=0,lazyPrivateState={relationships={}},sharedState=state{
        tribeID=tribe or 't',name=id,isFemale=female,lifeStageIndex=2,ageFraction=0.3,moods={4,4},statusEffects={},orderQueue={}}}
    objects[id]=s;return s
end
local a,b,c=person('a',true),person('b',false),person('c',false,'enemy')
for i=1,2 do objects['bed'..i]={uniqueID='bed'..i,objectTypeIndex=2,pos=i*3,sharedState=state{tribeID='t'}}end
local archive=dofile(ROOT..'/FamilyTree/scripts/familyTree/archive.lua').new({
    dataForKey=function(_,key)return saved[key]end,setDataForKey=function(_,value,key)saved[key]=value end})
local gom={objectSets={beds=1},getObjectWithID=function(_,id)return objects[id]end,saveObject=function()end,
    callFunctionForAllSapiensInTribe=function(_,tribe,fn)for _,s in pairs(objects)do if s.objectTypeIndex==1 and s.sharedState.tribeID==tribe then fn(s)end end end,
    getGameObjectsInSetWithinRadiusOfPos=function()return {{objectID='bed1',distance2=9},{objectID='bed2',distance2=36}}end,
    sendNotificationForObject=function(_,s,index,_,tribe)assert(s==a and index==17 and tribe=='t');notifications=notifications+1 end}
local world={getWorldTime=function()return now end,getPlayerSapienCount=function()return pop end,
    tribeIDForClientID=function(_,id)if id=='owner' then return 't' end end,
    skillPrioritiesOrLimitedAbilityChanged=function(_,tribe)assert(tribe=='t')end}
local service={archive=archive,gom=gom,world=world,isSapien=function(_,s)return s and s.objectTypeIndex==1 and s.sharedState end}
local sapiens={
    cancelAllOrders=function(_,s)s.sharedState.orderQueue={};return true end,
    cancelOrderAtQueueIndex=function(_,s,i)table.remove(s.sharedState.orderQueue,i);s.sharedState.actionState=nil end,
    dropHeldInventoryImmediately=function()end,cancelWaitOrder=function()end,
    startNextAction=function(_,s)s.sharedState.actionState.progressIndex=s.sharedState.actionState.progressIndex+1 end}
modules['server/serverSapien']=sapiens
local unreachable
modules['server/sapienAI/ai']={addOrderIfAble=function(_,s,order,bed,context)
    if s.uniqueID==unreachable then return false end
    s.sharedState.orderQueue={{orderTypeIndex=order,objectID=bed,context=context}}
    s.sharedState.actionState={sequenceTypeIndex=201,progressIndex=1};return true
end}
local conception=dofile(ROOT..'/FamilyTree/scripts/familyTree/conception.lua')
conception:init(service)
local function req(action,id,partner)return conception:request(service,'owner',{action=action,id=id or 'a',partner=partner})end
local function inspect()return req('inspect','a','b')end
local function start()local r=req('start','a','b');assert(r.busy,r.error);return r end
local function tick(dt)now=now+(dt or 1);conception:update(service)end
local function arrive()
    for i,s in ipairs({a,b})do s.pos=objects['bed'..i].pos;s.sharedState.actionState.progressIndex=2 end
    tick();assert(a.sharedState.actionState.progressIndex==3 and b.sharedState.actionState.progressIndex==3)
end
local key=rules.key('a','b')
assert(key==rules.key('b','a') and rules.age(constants,a.sharedState)==30)
assert(inspect().available and inspect().likelihood=='High')
assert(select(2,rules.chance(50,80,0,0,5,149,0.1))=='Low')
assert(select(2,rules.chance(40,50,0,0,5,20,1))=='Medium')
assert(conception:request(service,'intruder',{action='start',id='a',partner='b'}).error)
assert(req('start','a','c').error and req('start','a','a').error and req('start','bed1','b').error)
assert(conception:request(service,'owner',{action='start',id='a',partner='b',probability=1}).error)
assert(conception:request(service,'owner',{action='list',id='a',page=0/0}).error)
assert(conception:request(service,'owner',{action='list',id='a',page=math.huge}).error)
assert(req('start','a:foreign','b').error)
local list=req('list');assert(list.count==1 and list.rows[1].id=='b')
storage.foodCountsByTribeID.t=0;assert(not inspect().available);storage.foodCountsByTribeID.t=50
growth=false;assert(not inspect().available);growth=true
pop=150;assert(not inspect().available);pop=20
a.sharedState.hungry=true;assert(not inspect().available);a.sharedState.hungry=nil
a.sharedState.moods[1]=1;assert(not inspect().available);a.sharedState.moods[1]=4
a.sharedState.ageFraction=0.04;assert(not inspect().available);a.sharedState.ageFraction=0.3
a.sharedState.ageFraction=0.71;assert(not inspect().available);a.sharedState.ageFraction=0.3
a.sharedState.hasBaby=true;assert(not inspect().available);a.sharedState.hasBaby=nil
b.lazyPrivateState.relationships.a={familyRelationshipType=constants.familyRelationshipTypes.sibling}
assert(not inspect().available);b.lazyPrivateState.relationships.a=nil
objects.bed2.pos=100;assert(not inspect().available);objects.bed2.pos=6
objects.bed2.objectTypeIndex=3;assert(not inspect().available);objects.bed2.objectTypeIndex=2
objects.bed2.sharedState.assignedBedSapienID='c';assert(not inspect().available);objects.bed2.sharedState.assignedBedSapienID=nil
objects.bed2.sharedState.seatNodes={{sapienID='c'}};assert(not inspect().available);objects.bed2.sharedState.seatNodes=nil

-- Both must arrive. Repeated starts cannot restart or reroll the pair.
start();assert(req('start','b','a').error)
a.sharedState.actionState.progressIndex=2;a.pos=objects.bed1.pos
tick(3);assert(a.sharedState.actionState.progressIndex==2)
arrive();tick(11);assert(inspect().busy)
tick();assert(inspect().failures==1 and not a.sharedState.ftPair and not objects.bed1.sharedState.ftPair)
-- Reload while travelling, then while meeting, preserves the active event.
start();conception:init(service);arrive();conception:init(service);tick(12)
assert(inspect().failures==2)
start();arrive();tick(12)
assert(inspect().failures==3 and inspect().remainingYears==5 and not inspect().available)
assert(req('start','b','a').error)
conception:init(service);tick(100000)
assert(inspect().remainingYears==5,'Elapsed world time alone is not age progress')
a.sharedState.ageFraction=0.399;assert(inspect().remainingYears>0)
a.sharedState.ageFraction=0.4;assert(inspect().available and inspect().failures==0)

-- Natural pregnancies have priority and are never counted as a failed attempt.
start();arrive()
a.sharedState.pregnant=true;a.sharedState.pregnancyOrBabyTimer=123
a.sharedState.pregnancyFatherInfo={fatherID='natural-father'}
tick(12)
assert(not conception.active[key] and archive:get(key).failures==0)
assert(a.sharedState.pregnancyOrBabyTimer==123 and a.sharedState.pregnancyFatherInfo.fatherID=='natural-father')
a.sharedState.pregnant=nil
-- Job interruption preserves the replacement job; travel failures do not count.
start();b.sharedState.orderQueue={{orderTypeIndex=999}};tick()
assert(b.sharedState.orderQueue[1].orderTypeIndex==999 and inspect().failures==0)
unreachable='b';assert(req('start','a','b').error);unreachable=nil
assert(not a.sharedState.ftPair and not objects.bed2.sharedState.ftPair and inspect().failures==0)
start();tick(313);assert(not conception.active[key] and inspect().failures==0)
start();objects.bed2.sharedState.seatNodes={{sapienID='c'}};tick()
assert(not conception.active[key] and inspect().failures==0);objects.bed2.sharedState.seatNodes=nil
start();arrive();b.pos=100;tick();assert(not conception.active[key] and inspect().failures==0);b.pos=0
-- Unloaded participants retain a marker until their object returns.
start();objects.b=nil;tick(20);assert(not conception.active[key] and b.sharedState.ftPair)
objects.b=b;conception:cleanup(service,b)
assert(not b.sharedState.ftPair and #b.sharedState.orderQueue==0)
-- A completed successful roll uses vanilla pregnancy state and notifications.
roll=0;start();arrive();tick(12)
assert(a.sharedState.pregnant and a.sharedState.pregnancyFatherInfo.fatherID=='b')
assert(a.sharedState.pregnancyOrBabyTimer==0 and notifications==1 and updates==1)
tick(100);assert(notifications==1 and archive:get(key).failures==0)
print('PASS conception: native age clock, requirements, server authorization, pair selection, three failures, five-year cooldown, reload, travel/meeting cancellations, natural pregnancy preservation and one-shot success')

-- Generic plans may not bypass the authenticated pair endpoint.
modules['common/plan']={types={ftTryForBaby={index=301}}}
local forwarded=0
local plans={addPlans=function()forwarded=forwarded+1 end}
dofile(ROOT..'/FamilyTree/scripts/server/planManager.lua'):onload(plans)
plans:addPlans('t',{planTypeIndex=301});assert(forwarded==0)
plans:addPlans('t',{planTypeIndex=1});assert(forwarded==1)
-- The native AI must keep stationary actions pending instead of auto-finishing.
modules['common/action']={types={moveTo={index=1},idle={index=2},ftWaitForPartner={index=3},ftSpendTimeTogether={index=4}}}
local ai={updateInfos={}}
dofile(ROOT..'/FamilyTree/scripts/server/sapienAI/activeOrderAI.lua'):onload(ai)
assert(ai.updateInfos[3].checkFrequency==math.huge and ai.updateInfos[4].allowCompletionWithoutSkill)
local initCalled=false
local animation={init=function()initCalled=true end}
dofile(ROOT..'/FamilyTree/scripts/logicThread/clientSapienAnimation.lua'):onload(animation)
animation:init();assert(initCalled and modules['common/actionSequence'].types.ftTryForBaby.actions[3]==2)
local chosen
modules['common/animationGroups']={groups={[1]={animations={ftSpendTimeTogether={index=77}}}}}
local clientAnimation={changeAnimation=function(_,_,index)chosen=index end}
dofile(ROOT..'/FamilyTree/scripts/logicThread/clientObjectAnimation.lua'):onload(clientAnimation)
a.sharedState.actionState={sequenceTypeIndex=201,progressIndex=3}
clientAnimation:changeAnimation(a,2,1,1);assert(chosen==77)
a.sharedState.actionState.progressIndex=1;clientAnimation:changeAnimation(a,2,1,1);assert(chosen==2)
print('PASS conception adapters: generic plan rejection, stationary AI registration, safe native animation fallback and custom pose selection')
