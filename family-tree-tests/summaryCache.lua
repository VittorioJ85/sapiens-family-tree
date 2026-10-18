local source=os.getenv('FAMILY_TREE_TEST_SOURCE') or (ROOT or '.')..'/FamilyTree'
local Archive=dofile(source..'/scripts/familyTree/archive.lua')
local stats=dofile(source..'/scripts/familyTree/familyStats.lua')
local values,reads={},0
local db={dataForKey=function(_,k)reads=reads+1;return values[k]end,setDataForKey=function(_,v,k)values[k]=v end}
local a=Archive.new(db)
local n=5000
for i=1,n do a:observe({id=tostring(i),tribeID='t',surname='Family'..math.floor((i-1)/50),father=(i-1)%50>0 and tostring(i-1) or nil})end
a=Archive.new(db)
local live={}
local gom={getObjectWithID=function(_,id)return live[id]end}
local constants={getAgeValue=function(_,s)return s.age end}
local method=stats.summary or stats.page -- old release is the performance baseline
local function all(id)
    local page,revision,calls,total,oldest=0,nil,0,{living=0,deceased=0,unknown=0},nil
    while true do
        local p=method(stats,id,'t',page,a,gom,constants,revision)
        assert(not p.error,p.error);calls=calls+1;assert(calls<10000)
        revision=p.revision
        if not p.pending then
            for _,key in ipairs({'living','deceased','unknown'})do total[key]=total[key]+p[key]end
            if p.oldest and (not oldest or p.oldest.age>oldest.age or (p.oldest.age==oldest.age and p.oldest.id<oldest.id))then oldest=p.oldest end
            if p.done then break end
            page=page+1
        end
    end
    total.oldest=oldest
    return total,calls
end
local start=os.clock();reads=0
local first,cold=all('50');assert(first.unknown==50)
print(string.format('SUMMARY cold n=%d calls=%d reads=%d cpu=%.4fs',n,cold,reads,os.clock()-start))
start=os.clock();reads=0
local second,warm=all('50');assert(second.unknown==50)
print(string.format('SUMMARY warm n=%d calls=%d reads=%d cpu=%.4fs',n,warm,reads,os.clock()-start))
assert(warm==2 and reads<=50,'reopening must read only 50 family members, not the 5000-member tribe')
-- Counts/oldest must refresh without a database revision (load/unload/age/name).
live['1']={sharedState={tribeID='t',age=20,name='First'}}
live['2']={sharedState={tribeID='t',age=40,name='Second'}}
local t=all('50');assert(t.living==2 and t.unknown==48 and t.oldest.id=='2')
live['1'].sharedState.age=60;t=all('50');assert(t.oldest.id=='1')
live['1']=nil;live['2'].sharedState.tribeID='foreign'
t=all('50');assert(t.living==0 and t.unknown==50)
local oldRevision=a.revision
a:observe({id='50',father='51',surname='Family1'})
assert(stats:summary('50','t',1,a,gom,constants,oldRevision).error,'reject mixed revisions')
t=all('50');assert(t.unknown==51,'parent/name changes invalidate lineage cache')
a:observe({id='50',surname='Own'});t=all('50');assert(t.unknown==1)
a:observe({id='50',deathTime=5});t=all('50');assert(t.deceased==1 and t.unknown==0)
a:put('recruitGroup:g',{surname='Own'})
a:observe({id='50',surnameGroup='g'});a:observe({id='51',surname='Own',surnameGroup='g'})
a:observe({id='150',surname='Own',surnameGroup='g'})
t=all('50');assert(t.deceased==1 and t.unknown==2)
-- 50 and 51 still share a biological surname line after the recruitment group
-- stops matching. Unrelated 150 must leave that family.
a:put('recruitGroup:g',{surname='Other'});t=all('50');assert(t.deceased==1 and t.unknown==1)
-- Separate roots reuse the tribe index; no ancestor records are fetched anew.
local _,calls=all('250');assert(calls==2)
-- At most four tribe indexes, and an archive reload never inherits stale caches.
for i=1,7 do
    stats:summary('none','empty'..i,0,a,gom,constants)
end
local count=0;for _ in pairs(a.statsIndexes)do count=count+1 end;assert(count==4)
assert(not Archive.new(db).statsIndexes)
print('PASS summary cache: family-only warm reads, current loaded/age state, parent/name/group/death invalidation, revision rejection, tribe eviction and world isolation')
