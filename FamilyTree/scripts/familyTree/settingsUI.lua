local mjm = mjrequire "common/mjm"
local buttons = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local entry = mjrequire "mainThread/ui/uiCommon/uiTextEntry"
local common = mjrequire "mainThread/ui/uiCommon/uiCommon"
local requests = mjrequire "familyTree/requestScope"
local model = mjrequire "familyTree/nameSettings"
local catalog = mjrequire "familyTree/nameCatalog"
local UI = {}
UI.__index = UI
function UI:close()
    requests.cancel(self)
    if self.input then entry:finishEditing(self.input, false); self.input=nil end
    self.serial = self.serial + 1
end
function UI:text(value,x,y,size)
    local v = TextView.new(self.view)
    v.font=Font(common.fontName,(size or 16)*self.scale); v.color=mj.textColor
    v.relativePosition=ViewPosition(MJPositionInnerLeft,MJPositionTop)
    v.baseOffset=mjm.vec3(x,-y*self.scale,2); v.text=value
    return v
end
function UI:button(value,x,y,w,fn,disabled)
    local v=buttons:create(self.view,mjm.vec2(w,28*self.scale),buttons.types.standard_10x3)
    v.relativePosition=ViewPosition(MJPositionInnerLeft,MJPositionTop)
    v.baseOffset=mjm.vec3(x,-y*self.scale,3)
    buttons:setText(v,value); buttons:setClickFunction(v,fn)
    buttons:setDisabled(v,disabled or false)
    return v
end
function UI:checkbox(label,on,x,y,fn)
    local v=buttons:create(self.view,mjm.vec2(26*self.scale,26*self.scale),buttons.types.toggle)
    v.relativePosition=ViewPosition(MJPositionInnerLeft,MJPositionTop)
    v.baseOffset=mjm.vec3(x,-y*self.scale,3)
    buttons:setToggleState(v,on or false)
    buttons:setClickFunction(v,function() fn(buttons:getToggleState(v)); self:render() end)
    self:text(label,x+34,y+5)
    return v
end
function UI:load(reset)
    self:close(); self.busy=false; self.inputText=""
    self.view:removeAllSubviews()
    self:text("Loading name settings...",15,55)
    local serial=self.serial
    requests.call(self, {action="getNameSettings"}, function(data)
        if serial ~= self.serial then return end
        if not data or not data.settings then
            self.error=(data and data.error) or "No server response. Try Reload."
            self.draft=nil
        else self.draft=reset and model:defaults() or data.settings; self.error=nil end
        self.page=0; self:render()
    end)
end
function UI:renderGroups(draft, width)
    local colWidth=(width-30)/2
    for i,key in ipairs(catalog.order) do
        local x=15+((i-1)%2)*colWidth
        local y=170+math.floor((i-1)/2)*37
        self:checkbox(catalog.labels[key],draft.cultures[key],x,y,function(on) draft.cultures[key]=on end)
        self:button("Names",x+colWidth-100,y,85,function() self.mode="names"; self.group=key; self.page=0; self:render() end)
    end
    self:text("Select multiple groups. Use Names to enable or disable individual surnames.",15,440,14)
    self:text("Existing family names stay unchanged.",15,466,14)
end

function UI:paging(count, pageSize)
    self:button("Previous",15,457,105,function() self.page=self.page-1; self:render() end,self.page==0)
    self:text("Page "..(self.page+1).." / "..math.max(1,math.ceil(count/pageSize)),135,463)
    self:button("Next",275,457,105,function() self.page=self.page+1; self:render() end,(self.page+1)*pageSize>=count)
end

function UI:renderNames(draft, width)
    local key=self.group
    local names=catalog:sortedNames(key=="custom" and draft.customNames or catalog.names[key])
    self:checkbox(catalog.labels[key].." enabled",draft.cultures[key],15,166,function(on) draft.cultures[key]=on end)
    self:button("Select all",width-250,166,110,function() for _,name in ipairs(names) do draft.excludedNames[name]=nil end; self:render() end)
    self:button("Clear all",width-130,166,110,function() for _,name in ipairs(names) do draft.excludedNames[name]=true end; self:render() end)
    local columns=math.max(1,math.floor((width-30)/230))
    local rows=9
    local pageSize=columns*rows
    local columnWidth=(width-30)/columns
    self.namePageSize=pageSize
    self.page=math.min(self.page,math.max(0,math.ceil(#names/pageSize)-1))
    for i=1,pageSize do
        local name=names[self.page*pageSize+i]
        local column=math.floor((i-1)/rows)
        local row=(i-1)%rows
        if name then self:checkbox(name,not draft.excludedNames[name],15+column*columnWidth,204+row*27,function(on) draft.excludedNames[name]=not on end) end
    end
    if #names==0 then self:text("Add names in the Custom list editor first.",25,215) end
    self:paging(#names,pageSize)
    self:text(tostring(#names).." names",width-140,463,14)
end

function UI:renderCustom(draft, width)
    self:text("Custom names ("..#draft.customNames.."/128). Add names separated by semicolons:",15,230)
    self.input=entry:create(self.view,mjm.vec2(width-150,30*self.scale))
    self.input.relativePosition=ViewPosition(MJPositionInnerLeft,MJPositionTop)
    self.input.baseOffset=mjm.vec3(15,-258*self.scale,3)
    entry:setAllowsEmpty(self.input,true); entry:setMaxChars(self.input,2048)
    entry:setText(self.input,self.inputText or "")
    -- Vanilla calls this unconditionally when finishing an allowed empty entry.
    entry:setFunction(self.input,function() end)
    entry:setChangedContinuousFunction(self.input,function(value) self.inputText=value end)
    self:button("Add",width-120,258,105,function()
        entry:finishEditing(self.input,true)
        local candidate={}
        for _,name in ipairs(draft.customNames) do candidate[#candidate+1]=name end
        for name in (entry:getText(self.input) or ""):gmatch("[^,;]+") do candidate[#candidate+1]=name end
        local valid,err=model:validateCustomNames(candidate)
        if valid then draft.customNames=valid; self.inputText=""; self.error=nil else self.error=err end
        self:render()
    end)
    local sortedCustom=catalog:sortedNames(draft.customNames)
    for i=1,5 do
        local index=self.page*5+i
        local name=sortedCustom[index]
        if name then
            self:text(name,25,300+(i-1)*31)
            self:button("Remove",width-120,295+(i-1)*31,105,function()
                for originalIndex,originalName in ipairs(draft.customNames) do
                    if originalName==name then table.remove(draft.customNames,originalIndex); break end
                end
                self.page=math.min(self.page,math.max(0,math.ceil(#draft.customNames/5)-1)); self:render()
            end)
        end
    end
    self:paging(#draft.customNames,5)
end

function UI:render()
    if self.input then entry:finishEditing(self.input,false); self.input=nil end
    self.view:removeAllSubviews()
    local width=self.view.size.x
    self:button("Reload",15,45,105,function() self:load() end,self.busy)
    if self.back then self:button("Back to Family",135,45,155,function() self:close(); self.back() end) end
    if self.busy then self:text("Saving settings...",15,90); return end
    if not self.draft then self:text(self.error or "Unavailable",15,90); return end
    local draft=self.draft
    self:button("Automatic names: " .. (draft.automatic and "ON" or "OFF"),15,85,270,function()
        draft.automatic=not draft.automatic; self:render()
    end)
    draft.inheritance=draft.inheritance or "paternal"
    self:checkbox("Paternal (father)",draft.inheritance=="paternal",310,85,function() draft.inheritance="paternal" end)
    self:checkbox("Maternal (mother)",draft.inheritance=="maternal",520,85,function() draft.inheritance="maternal" end)
    self.mode=self.mode or "groups"
    self:button("Culture groups",15,125,150,function() self.mode="groups"; self.page=0; self:render() end)
    self:button("Custom list editor",180,125,180,function() self.mode="custom"; self.page=0; self:render() end)
    draft.cultures=draft.cultures or catalog:selection(draft)
    draft.excludedNames=draft.excludedNames or {}
    if self.mode=="groups" then self:renderGroups(draft,width)
    elseif self.mode=="names" then self:renderNames(draft,width)
    else self:renderCustom(draft,width) end
    self:button("Save",15,501,105,function()
        if self.busy then return end
        if (self.inputText or ""):match("%S") then self.error="Click Add before saving the typed names."; self:render(); return end
        local valid,err=model:validate(draft)
        if not valid then self.error=err; self:render(); return end
        self.busy=true
        self:render() -- lock the draft until the server acknowledges this save
        local serial=self.serial
        requests.call(self,{action="setNameSettings",settings=valid},function(data)
            if self.serial~=serial then return end
            self.busy=false
            if data and data.timedOut then
                self.draft=nil
                self.error="Save outcome unknown. Reload to read the server settings before editing again."
                self:render()
                return
            end
            self.error=(data and data.error) or (data and data.settings and "Saved for this tribe." or "Save failed")
            if data and data.settings then self.draft=data.settings end
            self:render()
        end)
    end,self.busy)
    self:button("Defaults",135,501,105,function() self.draft=model:defaults(); self.page=0; self.inputText=""; self.error="Defaults selected. Click Save to apply."; self:render() end)
    if self.error then self:text(self.error,15,540,14) end
end
function UI.open(parent,back)
    local view=View.new(parent); view.size=mjm.vec2(parent.size.x,parent.size.y-(back and 65 or 0))
    view.relativePosition=ViewPosition(MJPositionCenter,MJPositionBottom)
    local instance=setmetatable({view=view,back=back,serial=0,page=0},UI)
    instance.scale=math.min(1,(view.size.y-8)/565)
    local reset=UI.resetNext; UI.resetNext=nil
    instance:load(reset)
    return instance
end
return UI
