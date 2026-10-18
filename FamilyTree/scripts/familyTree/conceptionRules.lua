-- Pure balancing rules for requested attempts. Vanilla reproduction never calls this module.
local rules = {bedDistance=12, searchDistance=60, duration=12, travelTimeout=300, maxActive=32}
local function clamp(x,lo,hi) return math.max(lo,math.min(hi,x)) end
function rules.key(a,b)
    if a>b then a,b=b,a end
    return "conception:pair:"..a..":"..b
end
function rules.age(constants,state) return constants:getAgeValue(state)+5 end
function rules.remaining(record,age)
    return math.max(0,(record.blockedUntilAge or 0)-age)
end
function rules.fail(record,age)
    record.failures=(record.failures or 0)+1
    if record.failures>=3 then record.failures=3;record.blockedUntilAge=age+5 end
end
function rules.chance(ageMother,ageFather,bond,happiness,food,population,suppression)
    -- Design probabilities, not medical estimates or vanilla hidden percentages.
    local youngMother=clamp((50-ageMother)/25,0,1)
    local youngFather=clamp((80-ageFather)/40,0,1)
    local probability=(0.15+0.30*youngMother+0.10*youngFather+
        0.15*clamp(bond/2,0,1)+0.10*clamp(happiness/5,0,1)+
        0.10*clamp(food/(population+1),0,1))*clamp(suppression,0,1)
    probability=clamp(probability,0,0.85)
    return probability,probability<0.35 and "Low" or (probability<0.65 and "Medium" or "High")
end
return rules
