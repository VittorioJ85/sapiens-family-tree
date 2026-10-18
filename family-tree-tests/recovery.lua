-- Each interrupted write is followed by a fresh Archive and an out-of-order
-- observation. The adapter models ordered atomic key writes, not native fsync.
local source=os.getenv('FAMILY_TREE_TEST_SOURCE') or (ROOT or '.')..'/FamilyTree'
local Archive=dofile(source..'/scripts/familyTree/archive.lua')
local function clone(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out
end
local function database(data)
    return {data=clone(data or {}),writes=0,
        dataForKey=function(self,k)return clone(self.data[k])end,
        setDataForKey=function(self,v,k)
            self.writes=self.writes+1
            if self.writes==self.fail and not self.after then error('interrupted before '..k)end
            self.data[k]=clone(v)
            if self.writes==self.fail then error('interrupted after '..k)end
        end}
end
local cases=0
for _,size in ipairs({0,31,32,33})do
    local seed=database();local a=Archive.new(seed)
    for i=1,size do a:observe({id='old'..i,tribeID='t',mother='m',father='f'})end
    local snapshot=clone(seed.data)
    local row={id='a',tribeID='t',mother='m',father='f',deathTime=12,status='deceased'}
    local count=database(snapshot);a=Archive.new(count);count.writes=0;a:observe(row)
    for fail=1,count.writes do
        for _,after in ipairs({false,true})do
            local db=database(snapshot);a=Archive.new(db);db.writes=0;db.fail=fail;db.after=after
            assert(not pcall(function()a:observe(row)end))
            db.fail=nil;a=Archive.new(db)
            a:observe({id='b',tribeID='t',mother='m',father='f'})
            a:observe(row)
            for _,index in ipairs({'tribe:t','children:m','children:f'})do
                local seen,total={},0
                for page=0,math.floor((size+1)/32)do
                    local ids,n=a:list(index,page);assert(n==size+2,'wrong count after interruption')
                    for _,id in ipairs(ids)do assert(not seen[id],'duplicate '..id);seen[id]=true;total=total+1 end
                end
                assert(total==size+2 and seen.a and seen.b)
            end
            assert(a:hasMember('t','a') and a:person('a').deathTime==12)
            assert(not db.data.pendingWrite)
            cases=cases+1
        end
    end
end
-- Recovery must finish even if the deceased object can never be observed again.
local db=database();local a=Archive.new(db)
local set=db.setDataForKey
function db:setDataForKey(v,k)if k=='list:tribe:t:0' then error('index failure')end;return set(self,v,k)end
assert(not pcall(function()a:observe({id='dead',tribeID='t',deathTime=7})end))
db.setDataForKey=set;a=Archive.new(db)
assert(a:hasMember('t','dead') and select(2,a:list('tribe:t',0))==1)
-- Same-instance retry must finish the old operation before a new one is planned.
db=database();a=Archive.new(db);db.writes=0;db.fail=3
assert(not pcall(function()a:observe({id='first',tribeID='t'})end))
db.fail=nil;a:observe({id='second',tribeID='t'})
assert(a:hasMember('t','first') and select(2,a:list('tribe:t',0))==2)
-- Readers also recover after a caught failure. A second interruption while
-- recovering must leave the original intent intact for the next attempt.
db=database();a=Archive.new(db);db.writes=0;db.fail=3
assert(not pcall(function()a:observe({id='read',tribeID='t'})end))
db.writes=0;db.fail=2
assert(not pcall(function()Archive.new(db)end))
db.fail=nil
assert(a:hasMember('t','read') and select(2,a:list('tribe:t',0))==1)
local bad=database({schema=1,pendingWrite={version=1,writes={{key='schema',value={}}}}})
assert(not pcall(function()Archive.new(bad)end) and bad.data.schema==1,'reject malformed intent before writing')
print('PASS recovery: '..cases..' before/after write interruptions, page boundaries, out-of-order replay, absent deceased and same-instance retry')
