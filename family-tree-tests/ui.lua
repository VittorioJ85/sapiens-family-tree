local modules, pending, callbacks = {}, {}, {}
modules['familyTree/nameCatalog']=CATALOG
local function newView(parent)
    local view = {size = {x = 1140, y = 640}, children = {}}
    function view:removeAllSubviews() self.children = {} end
    function view:removeSubview(child)
        for i, v in ipairs(self.children) do if v == child then table.remove(self.children,i); break end end
    end
    function view:setModel() end
    function view:setClipChildren(value) self.clips=value end
    if parent then table.insert(parent.children, view) end
    return view
end
View, TextView, ColorView = {new = newView}, {new = newView}, {new = newView}
ViewPosition = function(...) return {...} end
Font = function(...) return {...} end
mj = {textColor = {}, enum = function(_, names)
    local t = {}; for i, name in ipairs(names) do t[i], t[name] = name, i end; return t end}
modules['common/mjm'] = {vec2 = function(x,y) return {x=x,y=y} end,
    vec3 = function(x,y,z) return {x=x,y=y,z=z} end, vec4=function(...)return {...}end}
modules['mainThread/ui/uiCommon/uiCommon'] = {fontName = "font", unSelectedTabZOffset = 0, selectedTabZOffset = 1}
modules['mainThread/ui/uiCommon/uiGameObjectView'] = {types={backgroundCircle=1},
    create=function(_,parent,size)local v=newView(parent);v.size=size;return v end,
    setObject=function()end}
modules['common/locale'] = {get = function(_, key) return key end}
local buttons = {standardTabSize = {x=180,y=55}, standardTabPadding = 10, types = {standard_10x3 = 1,tabTitle = 2}}
function buttons:create(parent, size) local v = newView(parent); v.size = size; v.isButton = true; return v end
function buttons:setText(v, text) v.text = text end
function buttons:setIconModel(v, icon) v.icon = icon end
function buttons:setClickFunction(v, fn) v.click = fn end
function buttons:setDisabled(v, disabled) v.disabled = disabled end
function buttons:setToggleState(v,on) v.toggle=on end
function buttons:getToggleState(v) return v.toggle end
function buttons:setSelected(v, selected) v.selected = selected end
modules['mainThread/ui/uiCommon/uiStandardButton'] = buttons
modules['mainThread/logicInterface'] = {callServerFunction = function(_, name, request, callback)
    assert(name == "familyTreeRequest"); table.insert(pending, {request=request, callback=callback}) end}
modules['mainThread/playerSapiens'] = {getFollowerInfos = function() return {x = {sharedState = {name = "Selected", tribeID = "t"}}} end}
modules['mainThread/playerSapiens'].getInfo = function(_, id)
    if id == 'x' then return {uniqueID=id,sharedState={name='Selected',tribeID='t'}} end
end
local zoomed
modules['mainThread/ui/gameUI'] = {followObject=function(_, person, terrain, options)
    assert(not terrain and options.dismissAnyUI and options.stopWhenClose); zoomed=person.uniqueID end}
modules['mainThread/ui/hubUI'] = {setLookAtInfo=function() end,showInspectUI=function() end}
modules['mainThread/eventManager'] = {addControllerCallback = function(_, _, _, key, fn) callbacks[key] = fn end}
-- Use the actual installed Hammerstone patch's appliesTo rules, with the
-- vanilla-file existence check from its modManager. Keep rendering mocked.
local patch = assert(loadfile(HAMMERSTONE_VIEW_PATCH))()
local function validatePatchTarget(name)
    for _, pattern in ipairs(patch.appliesTo) do
        if name:match("^" .. pattern .. "$") == name then
            local file = io.open(GAME .. "/GameResources/scripts/" .. name .. ".lua", "rb")
            assert(file, "[Hammerstone] No file to patch found: " .. name)
            file:close()
        end
    end
end
local ok, err = pcall(validatePatchTarget, "mainThread/ui/manageUI/familyTreeUI")
assert(not ok and err:find("No file to patch found", 1, true), "old namespace must reproduce reported error")
validatePatchTarget("familyTree/ui")
mjrequire = function(name) validatePatchTarget(name); return assert(modules[name], name) end
modules['common/timer']={addCallbackTimer=function(_,delay,fn)return {fn=fn}end,removeTimer=function()end}
modules['familyTree/requestScope']=dofile(ROOT..'/FamilyTree/scripts/familyTree/requestScope.lua')
modules['familyTree/treeModel']=dofile(ROOT..'/FamilyTree/scripts/familyTree/treeModel.lua')
modules['familyTree/treeView']=dofile(ROOT..'/FamilyTree/scripts/familyTree/treeView.lua')
local ui = dofile(ROOT .. "/FamilyTree/scripts/familyTree/ui.lua")
modules['familyTree/ui'] = ui
for _, name in ipairs({'inspectSapienTasks','inspectSapienInventory'}) do
    modules['mainThread/ui/inspect/' .. name] = {init = function() end, update = function() end,
        show = function(self) self.shown = true end, hide = function(self) self.shown = false end, popUI = function() return false end}
end
local panel = {}
dofile(ROOT .. "/FamilyTree/scripts/mainThread/ui/inspect/inspectSapienRelationshipsView.lua"):onload(panel)
modules['mainThread/ui/inspect/inspectSapienRelationshipsView'] = panel
local collection = dofile(GAME .. "/GameResources/scripts/mainThread/ui/inspect/manageSapienCollection.lua")
local content = newView()
local title
collection:init({setModalPanelTitleAndObject=function(_, value) title=value end}, {}, {}, content)
collection:show({uniqueID='x',sharedState={name='Selected'}})
assert(#pending == 0, "no family request until Family opens")
for _, v in ipairs(content.children) do
    if v.text == 'sapien_ui_relationships' and v.click then v.click() end
end
assert(title == 'Selected - sapien_ui_relationships')
assert(collection.modeTypes.relationships == 3 and #collection.modeTypes == 3)
local function click(text)
    for _, v in ipairs(ui.view.children) do if (v.text == text or (v.children[1] and v.children[1].text == text)) and v.click then v.click(); return end end
    error("Missing button " .. text)
end
assert(pending[#pending].request.id == "x")
assert(pending[#pending].request.action == "household")
local data={root={id="x",name="Selected",tribeID="t"},parents={},children={
    {id='child',name='Child',tribeID='t',coParentID='co',coParentName='Co-parent',parentRole='Father',
        coParent={id='co',name='Co-parent',tribeID='t',relationship='Mother'}}}}
pending[#pending].callback(data)
assert(ui.tree and #ui.tree.nodes==3)
assert(pending[#pending].request.action=='familySummary')
pending[#pending].callback({living=3,deceased=2,unknown=1,done=true,resolved=true,oldest={id='x',name='Selected',tribeID='t',age=63}})
assert(ui.oldestID=='x' and ui.summary.living==3)
local hitboxes={}
for _,v in ipairs(ui.view.children)do
    if v.isButton then
        local x,y=v.baseOffset.x,-v.baseOffset.y
        assert(x>=0 and y>=65 and x+v.size.x<=1140 and y+v.size.y<=640)
        for _,old in ipairs(hitboxes)do assert(x>=old.x2 or x+v.size.x<=old.x1 or y>=old.y2 or y+v.size.y<=old.y1,'Toolbar overlaps')end
        hitboxes[#hitboxes+1]={x1=x,x2=x+v.size.x,y1=y,y2=y+v.size.y}
        assert(not (v.children[1] and (v.children[1].text=='Overview' or v.children[1].text=='Explore tree')))
    end
end
click('Archive');assert(pending[#pending].request.action=='list' and not ui.tree)
pending[#pending].callback({rows={{id='relative',name='Relative',tribeID='t'}},count=1})
ui:select('relative');assert(pending[#pending].request.action=='household')
ui:popUI();assert(ui.listMode and pending[#pending].request.action=='list')
ui:popUI();assert(ui.id=='x' and not ui.listMode)
ui:select('relative');ui:home();assert(ui.id=='x' and #ui.history==0)
local oldRequest = pending[#pending]
collection:show({uniqueID='new',sharedState={name='New'}})
assert(ui.id == 'new' and ui.originID == 'new' and #ui.history == 0)
assert(title == 'New - sapien_ui_relationships')
local beforeSwitch = #ui.view.children
oldRequest.callback(data)
assert(#ui.view.children == beforeSwitch, 'late response from previous selected sapien')
ui:hide()
local before = #ui.view.children
pending[#pending].callback({error="stale callback"})
assert(#ui.view.children == before)
ui.hidden=false
ui:render(data)
local disabledZoom=false
for _,card in pairs(ui.tree.cards)do
    for _,v in ipairs(card.children)do if v.icon=='icon_inspect' and v.disabled then disabledZoom=true end end
end
assert(disabledZoom,'unavailable people cannot be zoomed to')
for _,v in ipairs(ui.tree.cards[ui.tree.model.root.key].children)do
    if v.icon=='icon_inspect' and not v.disabled then v.click();break end
end
assert(zoomed=='x' and ui.hidden, 'native zoom route and panel dismissal')
assert(not io.open(ROOT .. '/FamilyTree/scripts/mainThread/ui/manageUI/tribeCollection.lua'), 'obsolete tribe override removed')
print("PASS: actual native Family collection, selected-person entry, no eager requests, native title, navigation history, home, selection reset, UI bounds and stale responses (mock views)")
print("PASS: actual Hammerstone 1.8.4 patch rules reproduce old namespace failure and allow corrected UI path throughout collection initialization")
-- Both settings entry points share one editor and one server protocol.
local entry={}
function entry:create(parent,size) local v=newView(parent); v.size=size; return v end
function entry:setText(v,text) v.text=text end
function entry:getText(v) return v.text end
function entry:setAllowsEmpty() end
function entry:setMaxChars() end
function entry:setFunction(v,fn) v.finish=fn end
function entry:setChangedContinuousFunction(v,fn) v.changed=fn end
function entry:finishEditing(v) if v.finish then v.finish(v.text) end end
modules['mainThread/ui/uiCommon/uiTextEntry']=entry
modules['familyTree/nameSettings']=dofile(ROOT..'/FamilyTree/scripts/familyTree/nameSettings.lua')
local settings=dofile(ROOT..'/FamilyTree/scripts/familyTree/settingsUI.lua')
modules['familyTree/settingsUI']=settings
local function click(editor,label)
    for _,v in ipairs(editor.view.children) do if (v.text==label or (v.children[1] and v.children[1].text==label)) and v.click then v.click(); return end end
    error('Button not found: '..label)
end
ui.hidden=false; ui:render(data)
click(ui,'Names')
local editor=ui.settings
assert(pending[#pending].request.action=='getNameSettings')
pending[#pending].callback({settings=modules['familyTree/nameSettings']:defaults()})
click(editor,'Custom list editor')
editor.input.text='House A; House B; House A'
editor.input.changed(editor.input.text)
click(editor,'Add'); assert(#editor.draft.customNames==2)
editor.draft.cultures={custom=true}
click(editor,'Automatic names: OFF'); assert(editor.draft.automatic)
click(editor,'Save'); local saved=pending[#pending]
assert(saved.request.action=='setNameSettings' and #saved.request.settings.customNames==2)
assert(editor.busy)
for _,v in ipairs(editor.view.children) do
    assert(v.text~='Defaults' and v.toggle==nil, 'pending save must not allow draft edits')
end
saved.callback({settings=saved.request.settings})
assert(editor.error=='Saved for this tribe.')
click(editor,'Remove'); assert(#editor.draft.customNames==1)
click(editor,'Defaults'); assert(not editor.draft.automatic and next(editor.draft.cultures)==nil)
click(editor,'Reload'); local stale=pending[#pending]
ui:popUI(); assert(not ui.settings)
local before=#editor.view.children
stale.callback({settings=modules['familyTree/nameSettings']:defaults()})
assert(#editor.view.children==before,'closed settings must ignore late response')
-- Hammerstone adapters: other mods unaffected; opening refreshes; reset is explicit draft.
local forwarded=0
local hs={createControls=function() forwarded=forwarded+1 end,show=function() end,hide=function() end}
dofile(ROOT..'/FamilyTree/scripts/hammerstone/options/modOptionsUI.lua'):onload(hs)
hs:createControls(newView(),nil,'other',{},{}); assert(forwarded==1)
local small=newView(); small.size={x=740,y=510}
hs:createControls(small,nil,'familyTree',{},{}); hs:show()
pending[#pending].callback({settings=modules['familyTree/nameSettings']:defaults()})
for _,v in ipairs(hs.familyTreeSettings.view.children) do
    if v.baseOffset then
        assert(v.baseOffset.x>=0 and v.baseOffset.x<740)
        assert(-v.baseOffset.y>=0 and -v.baseOffset.y<510)
        if v.click then assert(v.baseOffset.x+v.size.x<=740 and -v.baseOffset.y+v.size.y<=510) end
    end
end
local manager={resetModOptions=function() forwarded=forwarded+1 end}
dofile(ROOT..'/FamilyTree/scripts/hammerstone/options/modOptionsManager.lua'):onload(manager)
manager:resetModOptions({configKey='other'}); assert(forwarded==2)
manager:resetModOptions({configKey='familyTree'}); assert(settings.resetNext)
hs:createControls(small,nil,'familyTree',{},{}); assert(not settings.resetNext)
pending[#pending].callback({settings={automatic=false,culture='roman',customNames={}}})
assert(not hs.familyTreeSettings.draft.automatic and next(hs.familyTreeSettings.draft.cultures)==nil)
hs:hide()
hs:show(); pending[#pending].callback({settings=modules['familyTree/nameSettings']:defaults()})
local cultural=hs.familyTreeSettings
local function inheritanceToggle(x)
    for _,v in ipairs(cultural.view.children) do
        if v.toggle~=nil and v.baseOffset.x==x and -v.baseOffset.y==85*cultural.scale then
            v.toggle=not v.toggle; v.click(); return
        end
    end
    error('Missing inheritance checkbox')
end
inheritanceToggle(520); assert(cultural.draft.inheritance=='maternal')
inheritanceToggle(520); assert(cultural.draft.inheritance=='maternal','cannot leave both unchecked')
inheritanceToggle(310); assert(cultural.draft.inheritance=='paternal')
inheritanceToggle(520)
local count=0
for _,v in ipairs(cultural.view.children) do
    if v.toggle~=nil and -v.baseOffset.y>150*cultural.scale then count=count+1; if count==3 then v.toggle=true; v.click(); break end end
end
assert(cultural.draft.cultures.japanese,'native checkbox enables additional group')
local count=0
for _,v in ipairs(cultural.view.children) do
    if v.text=='Names' and v.click then count=count+1; if count==3 then v.click(); break end end
end
assert(cultural.group=='japanese' and cultural.mode=='names')
assert(cultural.namePageSize==27,'740px panel should use three columns, nine rows')
local displayed={}
local member={}; for _,name in ipairs(CATALOG.names.japanese) do member[name]=true end
for page=0,math.ceil(128/cultural.namePageSize)-1 do
    cultural.page=page; cultural:render()
    local columns={}
    for _,v in ipairs(cultural.view.children) do
        if member[v.text] then assert(not displayed[v.text]); displayed[v.text]=true end
        if v.toggle~=nil and -v.baseOffset.y>=204*cultural.scale then
            columns[v.baseOffset.x]=true
            assert(v.baseOffset.x+v.size.x<=cultural.view.size.x)
            assert(-v.baseOffset.y+v.size.y<457*cultural.scale,'name boxes must not overlap paging')
        end
    end
    if page==0 then local n=0; for _ in pairs(columns) do n=n+1 end; assert(n==3) end
end
local total=0; for _ in pairs(displayed) do total=total+1 end
assert(total==128,'every surname appears once across grid pages')
cultural.view.size.x=1140; cultural.page=0; cultural:render()
assert(cultural.namePageSize==36,'wide Family panel should use four columns')
cultural.view.size.x=740; cultural.page=0; cultural:render()
local count=0
for _,v in ipairs(cultural.view.children) do
    if v.toggle~=nil and -v.baseOffset.y>150*cultural.scale then count=count+1; if count==2 then v.toggle=false; v.click(); break end end
end
assert(cultural.draft.excludedNames[CATALOG:sortedNames(CATALOG.names.japanese)[1]])
click(cultural,'Next'); assert(cultural.page==1)
click(cultural,'Clear all'); assert(cultural.draft.excludedNames.Saito)
click(cultural,'Select all'); assert(not cultural.draft.excludedNames.Saito)
click(cultural,'Save'); local selection=pending[#pending].request.settings
assert(selection.cultures.japanese and not selection.cultures.roman and not selection.cultures.greek)
assert(selection.inheritance=='maternal','save selected inheritance mode')
pending[#pending].callback({settings=selection})
hs:show(); local abandoned=pending[#pending]
local abandonedEditor=hs.familyTreeSettings
hs:createControls(newView(),nil,'familyTree',{},{});
assert(hs.familyTreeSettings~=abandonedEditor)
local oldCount=#abandonedEditor.view.children
abandoned.callback({settings=modules['familyTree/nameSettings']:defaults()})
assert(#abandonedEditor.view.children==oldCount,'replacing the Family Tree editor must cancel its old callbacks')
print('PASS settings UI: fallback without Hammerstone, editing, deduplication, saving, reset drafts, stale callbacks, optional Hammerstone hooks, small-panel bounds')

-- Run Hammerstone's real eager multi-mod initialization. Rendering remains mocked,
-- but createControls order, tab switching, and Reset come from installed code.
ModelView = {new=newView}
modules['common/material'] = {}
modules['common/model'] = {modelIndexForName=function(_,name) return name end}
modules['common/gameObject'] = {}
modules['hammerstone/logging'] = {schema=function() end}
for _, name in ipairs({'uiSlider','uiPopUpButton','uiToolTip'}) do
    modules['mainThread/ui/uiCommon/'..name] = {}
end
modules['mainThread/ui/uiCommon/uiSelectionLayout'] = setmetatable({}, {__index=function() return function() end end})
local listMethods = {valuesToTable=function(self) return self end,orderBy=function(self) return self end,ipairs=function(self) return ipairs(self) end}
local function list(values) return setmetatable(values or {},{__index=listMethods}) end
local function config(key,label)
    return {configKey=key,getStringValue=function() return key end,
        getStringOrNil=function() return {asLocalizedString=function() return label end} end,
        getTable=function() return list() end}
end
local optionsManager = {hasOptions=function() return true end,
    getModOptions=function() return list({config('familyTree','Family Tree'),config('preciseRotation','Precise Rotation')}) end,
    getModOptionsValues=function() return {} end,resetModOptions=function() return {} end}
dofile(ROOT..'/FamilyTree/scripts/hammerstone/options/modOptionsManager.lua'):onload(optionsManager)
local realHS = dofile(HAMMERSTONE_OPTIONS_UI)
dofile(ROOT..'/FamilyTree/scripts/hammerstone/options/modOptionsUI.lua'):onload(realHS)
local realRoot = newView()
realHS:init(realRoot,{changeTitle=function() end})
realHS:setModOptionsManager(optionsManager)
realHS:initOptions()
local initialEditor, initialRequest = realHS.familyTreeSettings, pending[#pending]
assert(initialEditor, 'eager creation of Precise Rotation must not close Family Tree')
initialRequest.callback({settings=modules['familyTree/nameSettings']:defaults()})
assert(initialEditor.draft, 'initial settings response must render the Family Tree editor')
local function findButton(view,label)
    if view.text==label and view.click then return view end
    for _,child in ipairs(view.children) do local found=findButton(child,label); if found then return found end end
end
realHS:show()
pending[#pending].callback({settings=modules['familyTree/nameSettings']:defaults()})
assert(findButton(initialEditor.view,'Automatic names: OFF'))
local serial=initialEditor.serial
findButton(realRoot,'Precise Rotation').click()
findButton(realRoot,'Family Tree').click()
assert(realHS.familyTreeSettings==initialEditor and initialEditor.serial==serial)
realHS:show(); local beforeHide=pending[#pending]
realHS:hide()
local closedSerial=initialEditor.serial
beforeHide.callback({settings={automatic=true,cultures={roman=true},customNames={}}})
assert(initialEditor.serial==closedSerial and not initialEditor.draft.automatic)
realHS:show()
local beforeReset=pending[#pending]
findButton(realRoot,'Reset to default').click()
local resetEditor=realHS.familyTreeSettings
assert(resetEditor~=initialEditor and settings.resetNext==nil)
beforeReset.callback({settings={automatic=true,cultures={roman=true},customNames={}}})
pending[#pending].callback({settings={automatic=true,cultures={roman=true},customNames={}}})
assert(resetEditor.draft and not resetEditor.draft.automatic and not resetEditor.draft.cultures.roman)
print('PASS real Hammerstone options: eager two-mod setup, response rendering, tab switching, hide/reopen and reset replacement')
