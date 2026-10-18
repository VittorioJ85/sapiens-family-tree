-- Exercise the public calendar, native event adapters and a multi-partner tree.
local Archive=dofile(ROOT..'/FamilyTree/scripts/familyTree/archive.lua')
local db={data={}}
function db:dataForKey(key)return self.data[key]end
function db:setDataForKey(value,key)self.data[key]=value end
local archive=Archive.new(db)
local now=80
local world={getDayLength=function()return 10 end,getYearLength=function()return 80 end,
    getWorldTime=function()return now end,tribeIDForClientID=function(_,id)return id=='owner' and 't' end}
local objects={}
local service={archive=archive,world=world,isSapien=function(_,o)return o and o.sharedState end}
function service:observe(object,extra)
    if not object then return end
    local row={id=object.uniqueID,name=object.sharedState.name,tribeID='t'}
    for k,v in pairs(extra or {})do row[k]=v end
    archive:observe(row)
end
local notifications=0
local gom={getObjectWithID=function(_,id)return objects[id]end,
    sendNotificationForObject=function(_,object,kind,payload,tribe)
        notifications=notifications+1;assert(tribe=='t' and payload.original);return 'native-result',42
    end}
service.gom=gom
local modules={['familyTree/service']=service,['common/notification']={types={babyBorn={index=7}}},
    ['familyTree/nameSettings']={},['familyTree/familyStats']={},['common/sapienConstants']={}}
mjrequire=function(name)return assert(modules[name],name)end
-- Run the installed game's age calculation and display formatter, not a copy.
mj={mToP=function(_,v)return v end,indexed=function(_,entries)
    for i,v in ipairs(entries)do v.index=i;entries[v.key]=v end;return entries
end,enum=function(_,entries)local t={};for i,k in ipairs(entries)do t[k]=i;t[i]=k end;return t end}
modules['common/mjm']={vec3=function()end}
modules['common/locale']={get=function(_,key)return key end}
local nativeAge=dofile(GAME..'/GameResources/scripts/common/sapienConstants.lua')
modules['common/sapienConstants']=nativeAge
dofile(ROOT..'/FamilyTree/scripts/server/serverGOM.lua'):onload(gom)
local requests=dofile(ROOT..'/FamilyTree/scripts/familyTree/requests.lua')
local mother={uniqueID='mother',sharedState={name='Mother',pregnancyFatherInfo={fatherID='father'}}}
local function notify(kind)return gom:sendNotificationForObject(mother,kind,{original=true},'t')end
notify(1);assert(not archive:get('pendingBirth:mother'))
local a,b=notify(7);assert(a=='native-result' and b==42 and notifications==2)
assert(archive:get('pendingBirth:mother').time==80)
-- Pending birth survives a save/reload and a failed child creation attempt.
archive=Archive.new(db);service.archive=archive
local succeed=false
local sapiens={createChildFromMother=function()
    if not succeed then return end
    objects.newborn={uniqueID='newborn',sharedState={name='Newborn'}}
    return 'newborn'
end}
dofile(ROOT..'/FamilyTree/scripts/server/serverSapien.lua'):onload(sapiens)
sapiens:createChildFromMother(mother);assert(archive:get('pendingBirth:mother'))
now=90;succeed=true;sapiens:createChildFromMother(mother)
assert(not archive:get('pendingBirth:mother'))
local child=archive:person('newborn')
assert(child.birthTime==80 and child.birthObservedTime==90 and child.father=='father')
archive:observe({id='newborn',birthTime=999,birthObservedTime=999,deathTime=241,status='deceased'})
archive:observe({id='newborn',deathTime=999,status='lastSeenAlive'})
local data=requests:handle(service,'owner',{action='person',id='newborn'})
assert(data.root.birthDate=='Year 2, Day 1' and data.root.childDate=='Year 2, Day 2')
assert(data.root.deathDate=='Year 4, Day 1' and data.root.status=='deceased')
archive:observe({id='old',tribeID='t',birthObservedTime=79.9})
data=requests:handle(service,'owner',{action='person',id='old'})
assert(not data.root.birthDate and data.root.childDate=='Year 1, Day 8','Child creation is not a birth date')
archive:observe({id='zero',tribeID='t',birthTime=0,deathTime=math.huge})
data=requests:handle(service,'owner',{action='person',id='zero'})
assert(data.root.birthDate=='Year 1, Day 1' and not data.root.deathDate)
print('PASS life dates: native notification forwarding, pending birth reload/failure/consumption, exact event dates, immutable timestamps, world-calendar boundaries and honest legacy unknowns')

for i,example in ipairs({{1,0,5},{1,0.99,14},{2,0,15},{2,0.5,40},{3,0.5,70}})do
    local id='age'..i
    archive:observe({id=id,name=id,tribeID='t'})
    local state={tribeID='t',name=id,lifeStageIndex=example[1],ageFraction=example[2]}
    objects[id]={uniqueID=id,sharedState=state}
    local row=requests:handle(service,'owner',{action='household',id=id}).root
    assert(row.age==example[3] and row.age==tonumber(nativeAge:getAgeDescription(state):match('^%d+')))
    assert(not archive:person(id).age,'A displayed age is a live snapshot, not a persisted stale value')
end
objects.age4.sharedState.ageFraction=0.52
assert(requests:handle(service,'owner',{action='person',id='age4'}).root.age==41,'Refresh reads the current native age')
objects.age4.sharedState.tribeID='another-player'
assert(not requests:handle(service,'owner',{action='person',id='age4'}).root.age,'Historical access must not leak current foreign-tribe age')
objects.age4=nil
assert(not requests:handle(service,'owner',{action='person',id='age4'}).root.age,'Unavailable ages remain unknown')
archive:observe({id='age5',status='deceased',deathTime=100,ageAtDeath=69})
local dead=requests:handle(service,'owner',{action='person',id='age5'}).root
assert(not dead.age and dead.ageAtDeath==69,'A stale live object must not change death age')
objects.age1.sharedState.ageFraction=0/0
assert(not requests:handle(service,'owner',{action='person',id='age1'}).root.age)
objects.age1.sharedState.ageFraction=0;objects.age1.sharedState.lifeStageIndex='child'
assert(not requests:handle(service,'owner',{action='person',id='age1'}).root.age)
archive:observe({id='age2',mother='age3',father='age4'})
local family=requests:handle(service,'owner',{action='household',id='age3'})
assert(family.children[1].age==14 and not family.children[1].coParent.age)
assert(requests:handle(service,'owner',{action='branch',id='age2',relation='parents'}).rows[1].age==15)
print('PASS living ages: native child/adult/elder display parity, birthdays on refresh, parents/children, no archive writes, foreign/unloaded privacy and deceased/invalid-state handling')

local function person(id,name,mother,father,tribe)
    archive:observe({id=id,name=name,mother=mother,father=father,tribeID=tribe or 't'})
end
person('f','Marcus Aurelius')
person('m1','Livia Marcia');person('m2','Julia Horatia');person('m3','Aelia Pompeia')
person('c1','Lucius Aurelius','m1','f');person('c2','Titus Aurelius','m2','f')
person('c3','Gaius Aurelius','m1','f');person('c4','Paula Aurelia','m3','f')
person('g1','Flavia Aurelia','partner','c1');person('partner','Claudia Aelia','gm','gf')
person('gm','Cornelia Aelia');person('gf','Publius Aelius')
person('private','Private Mother',nil,nil,'enemy');person('hiddenMomChild','Child','private','f')
data=requests:handle(service,'owner',{action='branch',id='f',relation='children'})
assert(data.rows[1].parentRole=='Father' and data.rows[1].coParentName=='Livia Marcia')
assert(not data.rows[5].coParentID and not data.rows[5].coParentName,'Private co-parent identity is redacted')
local Model=dofile(ROOT..'/FamilyTree/scripts/familyTree/treeModel.lua')
local largeStart={parents={{id='p1'},{id='p2'}},children={},nextPage=1}
for i=1,8 do largeStart.children[i]={id='k'..i,coParent={id='partner'..i,relationship='Mother'},parentRole='Father'} end
local bounded=Model.new({id='focus'},function()error('Initial family must not fetch further pages')end,function()end)
bounded:seedFamily(largeStart)
assert(bounded.count==19 and #bounded:layout()==19 and bounded.root.branches.children.nextPage==1)
local household=requests:handle(service,'owner',{action='household',id='f'})
assert(household.children[1].coParent.name=='Livia Marcia' and not household.children[5].coParent)
local seeded=Model.new(household.root,function()error('Seeded household must not issue branch requests')end,function()end)
seeded:seedFamily(household)
local initial=seeded:layout()
local seen={}
for _,node in ipairs(initial)do
    if node.row.id then assert(not seen[node.row.id],'Initial co-parents are shared');seen[node.row.id]=true end
end
assert(seen.f and seen.c1 and seen.c2 and seen.c3 and seen.c4 and seen.m1 and seen.m2 and seen.m3)
assert(not seen.g1 and not seen.partner and not seen.private,'No grandchildren or private people in the initial family')
seeded:toggle(seeded.root,'parents');seeded:toggle(seeded.root,'parents')
seeded:toggle(seeded.root,'children');seeded:toggle(seeded.root,'children')
seeded:collapseAll();seeded:toggle(seeded.root,'children')
assert(#seeded:layout()==6,'Collapse all remains a real reset; reopening reuses the first child page')
local calls=0
local model=Model.new(requests:handle(service,'owner',{action='person',id='f'}).root,function(request,callback)
    calls=calls+1;callback(requests:handle(service,'owner',request))
end,function()end)
local function open(node,direction,id)
    model:toggle(node,direction)
    for _,child in ipairs(node.branches[direction].children)do if child.row.id==id then return child end end
end
local c1=open(model.root,'children','c1')
local c2=model.root.branches.children.children[2]
local c4=model.root.branches.children.children[4]
open(c1,'parents','m1');open(c2,'parents','m2');open(c4,'parents','m3')
local g1=open(c1,'children','g1')
local partner=open(g1,'parents','partner');open(partner,'parents','gm')
local nodes,edges=model:layout()
local kids=model.root.branches.children.children
assert(math.abs(kids[1].x-kids[3].x)==Model.cardWidth+Model.gap,'Same-parent siblings must remain adjacent')
local connectedSibling=false
for _,edge in ipairs(edges)do
    if edge.from.row.id=='m1' and edge.to.row.id=='c3' then connectedSibling=true;assert(edge.role=='Mother')end
end
assert(connectedSibling,'An already visible mother must connect to all of her visible known children')
local usedPorts={}
for _,edge in ipairs(edges)do
    assert(edge.lower.generation==edge.upper.generation+1)
    assert(edge.trackY>edge.upper.y+Model.cardHeight/2 and edge.trackY<edge.lower.y-Model.cardHeight/2)
    for _,side in ipairs({'topPort','bottomPort'})do
        local key=edge.upper.generation..':'..side..':'..edge[side]
        assert(not usedPorts[key],'No unrelated links may share a vertical connector')
        usedPorts[key]=true
    end
    for _,other in ipairs(edges)do
        if edge~=other and edge.trackY==other.trackY then
            local lo,hi=math.min(edge.topPort,edge.bottomPort),math.max(edge.topPort,edge.bottomPort)
            local ol,oh=math.min(other.topPort,other.bottomPort),math.max(other.topPort,other.bottomPort)
            assert(hi<ol or oh<lo,'No overlapping horizontal family buses')
        end
    end
end
for i,node in ipairs(nodes)do
    for j=1,i-1 do
        local other=nodes[j]
        assert(math.abs(node.y-other.y)>=Model.cardHeight or math.abs(node.x-other.x)>=Model.cardWidth)
    end
end
assert(partner.branches.parents.children[1].generation==model.root.generation,'Maternal grandparents must retain their true generation')
local previous=calls;model:layout();assert(calls==previous)
-- Optional actual-model geometry export for visual QA; no world/save data.
local path=os.getenv('FAMILY_TREE_PREVIEW')
if path then
    local out=assert(io.open(path,'w'))
    for _,node in ipairs(nodes)do
        out:write(string.format('N\t%s\t%f\t%f\t%d\t%s\t%s\t%s\n',node.row.name or 'Unknown',node.x,node.y,node.generation,
            node.row.relationship or 'Focus',node.parent and node.parent.row.name or '',node.row.coParentName or ''))
    end
    for _,edge in ipairs(edges)do
        out:write(string.format('E\t%f\t%f\t%f\t%f\t%f\t%s\n',edge.topPort,edge.upper.y+Model.cardHeight/2,
            edge.trackY,edge.bottomPort,edge.lower.y-Model.cardHeight/2,edge.role or 'Unknown'))
    end
    out:close()
end
print('PASS multi-partner layout: grouped siblings, private co-parent redaction, compact maternal branches, distinct tracks and ports, correct generations, non-overlapping cards, no camera RPCs')
