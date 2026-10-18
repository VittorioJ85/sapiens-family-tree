-- Authenticated, server-owned pair attempts. Natural pregnancy timers and partner
-- selection are not intercepted. Only a successful completed meeting starts pregnancy.
local rules=mjrequire "familyTree/conceptionRules"
local constants=mjrequire "common/sapienConstants"
local objects=mjrequire "common/gameObject"
local math3=mjrequire "common/mjm"
local conception={}
local function orderType() return (mjrequire "common/order").types.ftTryForBaby.index end
local function sequenceType() return (mjrequire "common/actionSequence").types.ftTryForBaby.index end
local function validID(id) return type(id)=="string" and #id>0 and #id<=128 and not id:find("[:%s%c]") end
local function current(s,event)
    local q=s and s.sharedState.orderQueue and s.sharedState.orderQueue[1]
    return q and q.orderTypeIndex==orderType() and q.context and q.context.ftPair==event.key and q.context.ftSerial==event.serial
end
local function relation(a,b)
    return a.lazyPrivateState and a.lazyPrivateState.relationships and a.lazyPrivateState.relationships[b.uniqueID] or {}
end
local function score(r) return (r.bond and r.bond.short or 0)+(r.mood and r.mood.short or 0) end
function conception:cleanup(service,object)
    local state=object and object.sharedState
    if not service.archive or not state or not state.ftPair then return end
    local record=service.archive:get(state.ftPair)
    local event=record and record.event
    if event and event.phase~="finished" then return end
    -- A participant or bed may have unloaded before an interrupted event was
    -- released. Reconcile its persisted marker when it is loaded/used again.
    if service:isSapien(object) then
        local sapiens=mjrequire "server/serverSapien"
        for i=#(state.orderQueue or {}),1,-1 do
            local q=state.orderQueue[i]
            if q.orderTypeIndex==orderType() and q.context and q.context.ftPair==state.ftPair then
                sapiens:cancelOrderAtQueueIndex(object,i,false)
            end
        end
    end
    state:remove("ftPair");service.gom:saveObject(object.uniqueID)
end
local function owned(service,id,tribe)
    local s=service.gom:getObjectWithID(id)
    if service:isSapien(s) and s.sharedState.tribeID==tribe then
        conception:cleanup(service,s)
        return s
    end
end
local function unavailable(s,event)
    local st=s.sharedState
    if st.dead or st.nomad or st.pathStuckLastAttemptTime or
        (mjrequire "common/statusEffect"):cantDoMostWorkDueToEffects(st.statusEffects or {}) then return true end
    if st.ftPair and (not event or st.ftPair~=event.key) then return true end
    local orders=(mjrequire "common/order").types
    for _,q in ipairs(st.orderQueue or {}) do
        for _,name in ipairs({"fall","flee","fight","rrRememberAncestors","rrRememberTogether"}) do
            if orders[name] and q.orderTypeIndex==orders[name].index then return true end
        end
        if q.orderTypeIndex==orderType() and (not event or not current(s,event)) then return true end
    end
    return false
end
local function bedOK(service,bed,tribe,a,b,event)
    if not bed or not bed.sharedState then return false end
    local st,kind=bed.sharedState,objects.types[bed.objectTypeIndex]
    if not kind or not kind.isBed or not kind.isBuiltObject or st.tribeID~=tribe then return false end
    conception:cleanup(service,bed)
    if st.ftPair and (not event or st.ftPair~=event.key) then return false end
    if st.assignedBedSapienID and st.assignedBedSapienID~=a and st.assignedBedSapienID~=b then return false end
    for _,node in pairs(st.seatNodes or {}) do
        for _,id in ipairs({node.sapienID or false,node.assignedSapienID or false}) do
            if id and id~=a and id~=b then return false end
        end
    end
    return true
end
function conception:init(service)
    self.active=service.archive:get("conception:active") or {}
    self.lastTick=nil
    self.loadedAt=service.world:getWorldTime()
end
function conception:beds(service,a,b,event)
    local tribe=a.sharedState.tribeID
    if event then
        local x,y=service.gom:getObjectWithID(event.beds[1]),service.gom:getObjectWithID(event.beds[2])
        if x~=y and bedOK(service,x,tribe,a.uniqueID,b.uniqueID,event) and bedOK(service,y,tribe,a.uniqueID,b.uniqueID,event) and
            math3.length2(x.pos-y.pos)<=mj:mToP(rules.bedDistance)^2 then return {x,y} end
        return nil
    end
    local near=service.gom:getGameObjectsInSetWithinRadiusOfPos(service.gom.objectSets.beds,a.pos,mj:mToP(rules.searchDistance)) or {}
    table.sort(near,function(x,y) return (x.distance2 or 0)<(y.distance2 or 0) end)
    local found={}
    for _,info in ipairs(near) do
        local bed=service.gom:getObjectWithID(info.objectID)
        if bedOK(service,bed,tribe,a.uniqueID,b.uniqueID) then
            for _,other in ipairs(found) do
                if bed.uniqueID~=other.uniqueID and math3.length2(bed.pos-other.pos)<=mj:mToP(rules.bedDistance)^2 then return {other,bed} end
            end
            found[#found+1]=bed
            if #found>=64 then break end
        end
    end
end
function conception:evaluate(service,tribe,a,b,record,event)
    local result={available=false,failures=record.failures or 0}
    local function deny(reason) result.reason=reason;return result end
    if not a or not b or a==b then return deny("Choose two living members of your tribe.") end
    local sa,sb=a.sharedState,b.sharedState
    if sa.isFemale==sb.isFemale then return deny("Choose one female and one male Sapien.") end
    local mother,father=sa.isFemale and a or b,sa.isFemale and b or a
    local sm,sf=mother.sharedState,father.sharedState
    local age=rules.age(constants,sm)
    result.remainingYears=rules.remaining(record,age)
    if result.remainingYears>0 then return deny(string.format("Pair cooldown: %.1f age years remaining.",result.remainingYears)) end
    if record.blockedUntilAge then result.failures=0 end
    if sm.lifeStageIndex~=constants.lifeStages.adult.index or sf.lifeStageIndex<constants.lifeStages.adult.index or
        age<18 or rules.age(constants,sf)<18 or sm.ageFraction>constants.maxPregnancyLifeStageFraction then
        return deny("Both must be at least 18; the mother must be within the adult pregnancy age range.")
    end
    if sm.pregnant or sm.hasBaby then return deny("The selected mother is pregnant or caring for a baby.") end
    if unavailable(a,event) or unavailable(b,event) then return deny("A partner is unavailable, unwell, in danger, or already on a special visit.") end
    local ab,ba=relation(a,b),relation(b,a)
    if ab.familyRelationshipType or ba.familyRelationshipType then return deny("Close relatives cannot be selected.") end
    local mood=mjrequire "common/mood"
    local desire=mjrequire "common/desire"
    local foodNeed=(mjrequire "common/need").types.food.index
    for _,s in ipairs({a,b}) do
        if mood:getMood(s,mood.types.loyalty.index)<mood.levels.mildNegative then return deny("Both partners need sufficient loyalty.") end
        if desire:getDesire(s,foodNeed,false)>=desire.levels.strong then return deny("A partner is too hungry.") end
    end
    local tribeModule=mjrequire "server/serverTribe"
    if not tribeModule:tribeAllowsPopulationGrowth(tribe) then return deny("Population growth is disabled for this tribe.") end
    local population=math.max(0,tribeModule:getPopulation(tribe) or 0)
    local game=mjrequire "common/gameConstants"
    local cap=(mjrequire "server/serverWorldSettings"):get("populationCap") or game.populationLimitPerTribeSoftCap
    if population>=cap then return deny("The tribe has reached its population limit.") end
    local food=(mjrequire "server/serverStorageArea").foodCountsByTribeID[tribe] or 0
    if food<5 then return deny("Store at least 5 food items. Fruit on trees does not count.") end
    local function suppression(n,limit)
        local start=math.max(10,limit*0.8)
        local finish=math.max(start+1,limit*1.2)
        return math.max(0,math.min(1,(n-start)/(finish-start)))
    end
    local suppressed=suppression(population,game.populationLimitPerTribeSoftCap)
    if population>10 then suppressed=math.max(suppressed,suppression(service.world:getPlayerSapienCount() or 0,game.populationLimitGlobalSoftCap)) end
    if suppressed>=1 then return deny("Population pressure currently prevents conception.") end
    local beds=self:beds(service,a,b,event)
    if not beds then return deny("Need two free or pair-owned beds within 12 m of each other, near the selected Sapien.") end
    local happiness=(math.min(5,sa.moods[mood.types.happySad.index] or 0)+math.min(5,sb.moods[mood.types.happySad.index] or 0))/2
    result.probability,result.likelihood=rules.chance(age,rules.age(constants,sf),(score(ab)+score(ba))/2,happiness,food,population,1-suppressed)
    result.available=true
    return result,mother,father,beds
end
function conception:finish(service,event,record,message)
    event.phase="finished";record.event=event;record.message=message
    service.archive:put(event.key,record)
    self.active[event.key]=nil;service.archive:put("conception:active",self.active)
    local sapiens=mjrequire "server/serverSapien"
    for _,id in ipairs(event.members) do
        local s=service.gom:getObjectWithID(id)
        if s then
            if current(s,event) then sapiens:cancelOrderAtQueueIndex(s,1,false) end
            if s.sharedState.ftPair==event.key then s.sharedState:remove("ftPair");service.gom:saveObject(id) end
        end
    end
    for _,id in ipairs(event.beds) do
        local bed=service.gom:getObjectWithID(id)
        if bed and bed.sharedState.ftPair==event.key then bed.sharedState:remove("ftPair");service.gom:saveObject(id) end
    end
end
function conception:updateEvent(service,key)
    local record=service.archive:get(key)
    local event=record and record.event
    if not event or event.phase=="finished" then
        self.active[key]=nil;service.archive:put("conception:active",self.active);return
    end
    local now=service.world:getWorldTime()
    local a,b=owned(service,event.members[1],event.tribe),owned(service,event.members[2],event.tribe)
    if (not a or not b) and now-self.loadedAt<15 then return end
    if not a or not b or not current(a,event) or not current(b,event) or now-event.created>rules.travelTimeout+rules.duration then
        self:finish(service,event,record,"Attempt cancelled. No failure counted.");return
    end
    local status,mother,father,beds=self:evaluate(service,event.tribe,a,b,record,event)
    if not status.available then self:finish(service,event,record,"Attempt cancelled: "..status.reason);return end
    local ready=true
    for i,s in ipairs({a,b}) do
        local state=s.sharedState.actionState
        local progress=state and state.sequenceTypeIndex==sequenceType() and state.progressIndex
        local close=math3.length2(s.pos-beds[i].pos)<=mj:mToP(3)^2
        if event.phase=="meeting" and (progress~=3 or not close) then self:finish(service,event,record,"Meeting interrupted. No failure counted.");return end
        if progress~=2 or not close then ready=false end
    end
    local sapiens=mjrequire "server/serverSapien"
    if event.phase=="travelling" and ready then
        event.phase="meeting";event.started=now;record.event=event;service.archive:put(key,record)
        for _,s in ipairs({a,b}) do sapiens:startNextAction(s);service.gom:saveObject(s.uniqueID) end
    elseif event.phase=="meeting" and now-event.started>=rules.duration then
        -- Resolve only once on the server. A natural pregnancy detected above
        -- cancels this event instead of being replaced or counted as a failure.
        local success=(mjrequire "common/randomNumberGenerator"):randomValue()<status.probability
        if success then
            local sm,sf=mother.sharedState,father.sharedState
            sm:set("pregnant",true);sm:set("pregnancyOrBabyTimer",0)
            sm:set("pregnancyFatherInfo",{fatherID=father.uniqueID,skinColorFraction=sf.skinColorFraction,hairColorGene=sf.hairColorGene,eyeColorGene=sf.eyeColorGene})
            service.gom:saveObject(mother.uniqueID)
            record.failures=0;record.blockedUntilAge=nil
            self:finish(service,event,record,"Success! "..sm.name.." is pregnant.")
            service.gom:sendNotificationForObject(mother,(mjrequire "common/notification").types.becamePregnant.index,nil,event.tribe)
            service.world:skillPrioritiesOrLimitedAbilityChanged(event.tribe)
            local plans=mjrequire "server/planManager"
            plans:updateProximityForAbilityChange(mother.uniqueID)
        else
            rules.fail(record,rules.age(constants,mother.sharedState))
            self:finish(service,event,record,record.failures>=3 and "No pregnancy. This pair must wait 5 age years." or
                ("No pregnancy this time. Failed attempts: "..record.failures.." / 3."))
        end
    end
end
function conception:update(service)
    if not self.active or not next(self.active) then return end
    local now=service.world:getWorldTime()
    if self.lastTick and now-self.lastTick<1 then return end
    self.lastTick=now
    local keys={};for key in pairs(self.active) do keys[#keys+1]=key end
    for _,key in ipairs(keys) do self:updateEvent(service,key) end
end
function conception:request(service,clientID,request)
    if not service.archive or not self.active then return {error="Family Tree is loading."} end
    if type(request)~="table" or not validID(request.id) or
        (request.action~="list" and request.action~="inspect" and request.action~="start") then return {error="Invalid pair request."} end
    for key in pairs(request) do if key~="action" and key~="id" and key~="partner" and key~="page" then return {error="Invalid pair request."} end end
    local tribe=service.world:tribeIDForClientID(clientID)
    local a=tribe and owned(service,request.id,tribe)
    if not a then return {error="Select a living member of your tribe."} end
    if request.action=="list" then
        local page=request.page or 0
        if type(page)~="number" or page~=math.floor(page) or page<0 or page>10000 then return {error="Invalid page."} end
        local candidates={}
        service.gom:callFunctionForAllSapiensInTribe(tribe,function(s)
            if service:isSapien(s) and s.uniqueID~=a.uniqueID and s.sharedState.isFemale~=a.sharedState.isFemale and
                s.sharedState.lifeStageIndex>=constants.lifeStages.adult.index and rules.age(constants,s.sharedState)>=18 then candidates[#candidates+1]=s end
        end)
        table.sort(candidates,function(x,y) return (x.sharedState.name or x.uniqueID)<(y.sharedState.name or y.uniqueID) end)
        local rows={}
        for i=page*8+1,math.min(#candidates,(page+1)*8) do
            local s=candidates[i]
            local record=service.archive:get(rules.key(a.uniqueID,s.uniqueID)) or {}
            local value=self:evaluate(service,tribe,a,s,record)
            value.id=s.uniqueID;value.name=s.sharedState.name;rows[#rows+1]=value
        end
        return {rows=rows,count=#candidates,page=page,name=a.sharedState.name}
    end
    if not validID(request.partner) then return {error="Choose a partner."} end
    local b=owned(service,request.partner,tribe)
    if not b or b==a then return {error="Choose another living member of your tribe."} end
    local key=rules.key(a.uniqueID,b.uniqueID)
    local record=service.archive:get(key) or {failures=0,serial=0}
    if self.active[key] then
        if request.action=="start" then return {error="This pair is already meeting."} end
        return {busy=true,message=record.event.phase=="meeting" and "Spending time together..." or "Walking to the two beds..."}
    end
    local value,mother,father,beds=self:evaluate(service,tribe,a,b,record)
    value.message=record.message;value.name=b.sharedState.name
    if request.action=="inspect" then return value end
    if not value.available then return {error=value.reason} end
    local count=0;for _ in pairs(self.active) do count=count+1 end
    if count>=rules.maxActive then return {error="Too many meetings are already in progress."} end
    -- A duplicate network request cannot interrupt/restart an existing attempt.
    if record.blockedUntilAge then record.failures=0;record.blockedUntilAge=nil end
    record.serial=(record.serial or 0)+1
    local event={key=key,serial=record.serial,tribe=tribe,members={a.uniqueID,b.uniqueID},
        beds={beds[1].uniqueID,beds[2].uniqueID},phase="travelling",created=service.world:getWorldTime()}
    record.event=event;record.message=nil;service.archive:put(key,record)
    self.active[key]=true;service.archive:put("conception:active",self.active)
    local sapiens=mjrequire "server/serverSapien"
    for i,s in ipairs({a,b}) do
        s.sharedState:set("ftPair",key);beds[i].sharedState:set("ftPair",key)
        service.gom:saveObject(s.uniqueID);service.gom:saveObject(beds[i].uniqueID)
        if not sapiens:cancelAllOrders(s,false,true) then self:finish(service,event,record,"Could not start. No failure counted.");return {error=record.message} end
        local seats=mjrequire "server/objects/serverSeat"
        seats:removeAnyNodeAssignmentForSapien(s)
        sapiens:dropHeldInventoryImmediately(s)
        local ok=(mjrequire "server/sapienAI/ai"):addOrderIfAble(s,orderType(),beds[i].uniqueID,{ftPair=key,ftSerial=event.serial},
            (mjrequire "common/pathFinding").proximityTypes.reachable,mj:mToP(2))
        if not ok then self:finish(service,event,record,"A bed could not be reached. No failure counted.");return {error=record.message} end
        sapiens:cancelWaitOrder(s);service.gom:saveObject(s.uniqueID)
    end
    return {busy=true,message="Both partners are walking to their beds."}
end
return conception
