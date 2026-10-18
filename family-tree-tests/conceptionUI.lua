-- Native radial dispatch and modal lifecycle with simulated rendering/transport.
local modules,pending,timers={},{},{}
local function view(parent)
    local v={size={x=1140,y=640},children={}}
    function v:removeAllSubviews()self.children={}end
    if parent then parent.children[#parent.children+1]=v end
    return v
end
View,TextView={new=view},{new=view}
ViewPosition=function(...)return {...}end;Font=function(...)return {...}end
mj={textColor={}}
modules['common/mjm']={vec2=function(x,y)return{x=x,y=y}end,vec3=function(x,y,z)return{x=x,y=y,z=z}end}
modules['common/timer']={addCallbackTimer=function(_,delay,fn)local t={fn=fn,delay=delay};timers[t]=true;return t end,
    removeTimer=function(_,id)timers[id]=nil end}
local function fire(id)assert(timers[id]);timers[id]=nil;id.fn()end
modules['mainThread/ui/uiCommon/uiCommon']={fontName='test'}
local buttons={types={standard_10x3=1},create=function(_,parent,size)local v=view(parent);v.size=size;v.button=true;return v end,
    setText=function(_,v,t)v.text=t end,setDisabled=function(_,v,t)v.disabled=t end,setClickFunction=function(_,v,fn)v.click=fn end}
modules['mainThread/ui/uiCommon/uiStandardButton']=buttons
local logic={callServerFunction=function(_,name,data,callback)pending[#pending+1]={name=name,data=data,callback=callback}end}
modules['mainThread/logicInterface']=logic
local inspect={modalPanelView=view(),setModalPanelTitleAndObject=function()end,
    showModalPanelView=function(self,container,ui)self.current=container;self.ui=ui end,
    containerViewIsHidden=function(self,container)return self.current~=container or container.hidden end}
modules['mainThread/ui/inspect/inspectUI']=inspect
mjrequire=function(name)return assert(modules[name],name)end
local ui=dofile(ROOT..'/FamilyTree/scripts/familyTree/conceptionUI.lua')
modules['familyTree/conceptionUI']=ui
local function button(label)
    for _,v in ipairs(ui.container.children)do if v.button and v.text==label then return v end end
    error('Missing button: '..label)
end
local function reply(value)pending[#pending].callback(value)end
local function bounds()
    for _,v in ipairs(ui.container.children)do
        assert(v.baseOffset.x>=0 and v.baseOffset.x<1140 and -v.baseOffset.y<640)
        if v.button then assert(v.baseOffset.x+v.size.x<=1140)end
    end
end
local plan={types=setmetatable({ftTryForBaby={index=301}},{__index=function(t,k)local v={index=k};t[k]=v;return v end})}
modules['common/plan']=plan
dofile(ROOT..'/FamilyTree/scripts/mainThread/logicInterface.lua'):onload(logic)
local f=assert(io.open(GAME..'/GameResources/scripts/mainThread/ui/actionUI.lua','rb'))
local source=f:read('*a');f:close()
local nativeSend=assert(source:match('(local function sendPlan.-)\nlocal cachedAvailibilityResult'))
local chunk=assert(loadstring(nativeSend..'\nreturn sendPlan'))
setfenv(chunk,setmetatable({logicInterface=logic,plan=plan,actionUI={}},{__index=_G}))
local send=chunk()
send(301,{}, {'a'});assert(ui:isVisible() and pending[#pending].data.action=='list')
assert(pending[#pending].name=='familyTreeConception')
local hidden,dismissed=0,0
local radial={hide=function()hidden=hidden+1 end,animateOutForOptionSelected=function()dismissed=dismissed+1 end}
dofile(ROOT..'/FamilyTree/scripts/mainThread/ui/actionUI.lua'):onload(radial)
radial:animateOutForOptionSelected();assert(hidden==1 and dismissed==0)
reply({rows={{id='b',name='Partner',available=true,likelihood='High',failures=0}},count=1,page=0,name='Selected'})
assert(not next(timers));bounds()
button('Partner').click();assert(pending[#pending].data.partner=='b')
reply({available=true,name='Partner',probability=0.7,likelihood='High',failures=0})
assert(not button('Try for a Baby').disabled);bounds()
button('Try for a Baby').click();assert(pending[#pending].data.action=='start')
reply({busy=true,message='Walking'});assert(ui.pollTimer);bounds()
fire(ui.pollTimer);assert(pending[#pending].data.action=='inspect')
reply({available=false,reason='Pair cooldown: 5 age years remaining.',failures=3})
assert(button('Try for a Baby').disabled and not next(timers));bounds()
ui:refresh();local old=pending[#pending]
ui:hide();old.callback({error='Stale response'});assert(not ui:isVisible() and not next(timers))
radial:animateOutForOptionSelected();assert(dismissed==1)
local parent=inspect.modalPanelView
ui:open('a');assert(ui.container and #parent.children==1)
fire(ui.timeoutTimer);assert(not ui.pending)
button('Refresh').click();assert(ui.pending)
reply({error='Retryable server error'});assert(not ui.pending and not next(timers))
ui:open('a');local late=pending[#pending];ui:open('b')
late.callback({error='Obsolete selection'});assert(ui.pending and ui.id=='b')
reply({rows={},count=0,page=0,name='Other'});bounds()
assert(not button('Next').click or button('Next').disabled)
ui:hide();local n=#pending
send(301,{}, {'a','b'});assert(#pending==n and not ui:isVisible())
send(1,{}, {'a'});assert(pending[#pending].name=='addPlans')
inspect.modalPanelView=view();ui:open('a');assert(ui.parent~=parent and #inspect.modalPanelView.children==1)
ui:hide();assert(not next(timers))
print('PASS conception UI: actual native radial payload, modal retention, partner selection, greyed-out cooldown, status polling, timeout/retry, stale responses, reuse and world replacement')
