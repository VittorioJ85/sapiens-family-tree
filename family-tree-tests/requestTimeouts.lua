-- Execute real panel callbacks with controllable network delivery and timers.
local source=os.getenv('FAMILY_TREE_TEST_SOURCE') or (ROOT or '.')..'/FamilyTree'
local modules,pending,timers={},{},{}
local function view(parent)
    local v={size={x=1140,y=640},children={}}
    function v:removeAllSubviews()self.children={}end
    if parent then parent.children[#parent.children+1]=v end
    return v
end
View={new=view};TextView={new=view};Font=function()end;ViewPosition=function()end;mj={textColor={}}
modules['common/mjm']={vec2=function(x,y)return{x=x,y=y}end,vec3=function(x,y,z)return{x=x,y=y,z=z}end}
modules['mainThread/ui/uiCommon/uiCommon']={fontName='mock'}
modules['mainThread/playerSapiens']={}
modules['mainThread/ui/uiCommon/uiTextEntry']={}
local buttons={types={standard_10x3=1,toggle=2}}
function buttons:create(parent,size)local v=view(parent);v.size=size;return v end
function buttons:setText(v,t)v.text=t end
function buttons:setClickFunction(v,f)v.click=f end
function buttons:setDisabled(v,b)v.disabled=b end
function buttons:setToggleState(v,b)v.toggle=b end
modules['mainThread/ui/uiCommon/uiStandardButton']=buttons
modules['mainThread/logicInterface']={callServerFunction=function(_,name,data,fn)pending[#pending+1]={data=data,fn=fn}end}
modules['common/timer']={addCallbackTimer=function(_,delay,fn)assert(delay==10);local id={fn=fn};timers[id]=true;return id end,
    removeTimer=function(_,id)timers[id]=nil end}
mjrequire=function(name)
    if not modules[name] and name:match('^familyTree/') then modules[name]=dofile(source..'/scripts/'..name..'.lua')end
    return assert(modules[name],name)
end
local function expire()
    local id=next(timers);assert(id,'no recovery timer registered')
    timers[id]=nil;id.fn()
end
local function button(owner,text)
    for _,v in ipairs(owner.view.children)do if v.text==text and v.click and not v.disabled then return v end end
    error('no enabled '..text)
end
local ui=mjrequire('familyTree/ui')
ui:init(view());ui:show({uniqueID='a'})
local late=pending[#pending];expire();button(ui,'Refresh').click()
local active=pending[#pending]
late.fn({error='obsolete'});assert(ui.view.children[1].text=='Family Tree - Loading...')
active.fn({error='controlled server error'});assert(not next(timers));button(ui,'Refresh')
local children=ui.view.children;active.fn({error='duplicate'});assert(ui.view.children==children)
ui:request();late=pending[#pending];ui:hide();assert(not next(timers))
children=ui.view.children;late.fn({error='closed'});assert(ui.view.children==children)
local settings=mjrequire('familyTree/settingsUI');local model=mjrequire('familyTree/nameSettings')
local editor=settings.open(view());late=pending[#pending];expire();button(editor,'Reload').click()
active=pending[#pending];late.fn({settings=model:defaults()});assert(not editor.draft)
active.fn({settings=model:defaults()});button(editor,'Save').click();late=pending[#pending]
expire();assert(not editor.busy and not editor.draft and editor.error:find('unknown'))
button(editor,'Reload').click();active=pending[#pending]
late.fn({settings=model:defaults()});assert(not editor.draft,'late save acknowledgement must not restore old draft')
local server=model:defaults();server.inheritance='maternal'
active.fn({settings=server});assert(editor.draft.inheritance=='maternal')
button(editor,'Save').click();active=pending[#pending];active.fn({settings=server})
assert(not editor.busy and editor.error=='Saved for this tribe.' and not next(timers))
editor:load();editor:close();assert(not next(timers))
-- Separate companion/Family instances do not cancel one another's timers.
local a,b=settings.open(view()),settings.open(view());a:close();assert(next(timers));b:close();assert(not next(timers))
-- Statistics failure must leave the already rendered tree available.
ui.hidden=false;ui.tree={close=function()end,setSummary=function(_,s)assert(s.error)end}
ui:requestStats({root={id='a'}},ui.serial,0,{living=0,deceased=0,unknown=0})
expire();assert(ui.summary.error and ui.tree);ui:hide();assert(not next(timers))
print('PASS panel timeouts: initial Family, GET/SET settings, uncertain save reload, retry, late/duplicate replies, close, independent panels and stats timeout')
