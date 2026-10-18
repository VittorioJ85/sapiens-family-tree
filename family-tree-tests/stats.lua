local Archive=dofile(ROOT..'/FamilyTree/scripts/familyTree/archive.lua')
local stats=dofile(ROOT..'/FamilyTree/scripts/familyTree/familyStats.lua')
local values={}
local a=Archive.new({dataForKey=function(_,k) return values[k] end,setDataForKey=function(_,v,k) values[k]=v end})
local live={}
local gom={getObjectWithID=function(_,id) return live[id] end}
local constants={getAgeValue=function(_,s) return s.age end}
local function add(id,father,age,death)
    a:observe({id=id,name=id,tribeID='t',surname='Julius',father=father,deathTime=death})
    if age then live[id]={sharedState={name=id,tribeID='t',age=age}} end
end
add('father',nil,70); add('child','father',25); add('dead','father',nil,5)
add('absent','father'); add('unrelated',nil,90)
local s=stats:page('child','t',0,a,gom,constants)
assert(s.living==2 and s.deceased==1 and s.unknown==1 and s.oldest.id=='father')
assert(stats:lineage('unrelated',a)~=stats:lineage('father',a),'surname collision')
live.father=nil; a:observe({id='father',deathTime=100})
s=stats:page('child','t',0,a,gom,constants)
assert(s.oldest.id=='child' and s.living==1 and s.deceased==2)
live.child.sharedState.tribeID='elsewhere'
s=stats:page('child','t',0,a,gom,constants)
assert(not s.oldest and s.living==0 and s.unknown==2)
for i=1,80 do add('c'..i,'father',20) end
local total=0
for page=0,2 do local p=stats:page('father','t',page,a,gom,constants); total=total+p.living; assert(p.done==(page==2)) end
assert(total==80)
a:observe({id='mother',tribeID='t',surname='Claudia'})
a:observe({id='maternal',mother='mother',tribeID='t',surname='Claudia'})
assert(stats:lineage('maternal',a)=='mother')
print('PASS: family counts, separate homonyms, death succession, absent members, pagination, maternal fallback')
