-- One reusable native inspection modal. Responses are scoped to a generation
-- so changing selection or closing the panel cannot revive obsolete content.
local ui={serial=0,hidden=true,page=0}
local math3=mjrequire "common/mjm"
local buttons=mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local common=mjrequire "mainThread/ui/uiCommon/uiCommon"
local logic=mjrequire "mainThread/logicInterface"
local timer=mjrequire "common/timer"
function ui:cancelTimers()
    for _,key in ipairs({"pollTimer","timeoutTimer"}) do
        if self[key] then timer:removeTimer(self[key]);self[key]=nil end
    end
end
function ui:isVisible()
    return not self.hidden and self.container and not self.container.hidden and self.inspect and not self.inspect:containerViewIsHidden(self.container)
end
function ui:hide()
    self:cancelTimers()
    self.hidden=true;self.serial=self.serial+1;self.pending=false
    if self.container then self.container.hidden=true end
end
function ui:popUI()
    if self.partner then self.partner=nil;self:refresh();return true end
    return false
end
function ui:text(value,x,y,size)
    local view=TextView.new(self.container)
    view.font=Font(common.fontName,size or 16);view.color=mj.textColor
    view.relativePosition=ViewPosition(MJPositionInnerLeft,MJPositionTop)
    view.baseOffset=math3.vec3(x,-y,2);view.wrapWidth=self.container.size.x-x-30;view.text=value
    return view
end
function ui:button(label,x,y,width,fn,disabled)
    local view=buttons:create(self.container,math3.vec2(width,28),buttons.types.standard_10x3)
    view.relativePosition=ViewPosition(MJPositionInnerLeft,MJPositionTop);view.baseOffset=math3.vec3(x,-y,3)
    buttons:setText(view,label);buttons:setClickFunction(view,fn);buttons:setDisabled(view,disabled or false)
    return view
end
function ui:open(id)
    self:hide()
    local inspect=mjrequire "mainThread/ui/inspect/inspectUI"
    if self.parent~=inspect.modalPanelView then
        self.parent=inspect.modalPanelView
        self.container=View.new(self.parent)
        self.container.relativePosition=ViewPosition(MJPositionCenter,MJPositionCenter)
    end
    self.inspect=inspect;self.container.size=self.parent.size
    self.id,self.partner,self.page=id,nil,0
    inspect:setModalPanelTitleAndObject("Try for a Baby",nil)
    inspect:showModalPanelView(self.container,self)
    self.container.hidden=false;inspect.modalPanelView.hidden=false;self.hidden=false
    self:refresh()
end
function ui:send(action)
    if self.pending or not self:isVisible() then return end
    self:cancelTimers()
    self.serial=self.serial+1;local serial=self.serial;self.pending=true
    self.timeoutTimer=timer:addCallbackTimer(10,function()
        self.timeoutTimer=nil
        if serial~=self.serial or not self:isVisible() then return end
        self.serial=self.serial+1;self.pending=false
        self:render({error="The server did not respond. Refresh to check the current status."})
    end)
    logic:callServerFunction("familyTreeConception",{action=action,id=self.id,partner=self.partner,page=self.page},function(data)
        if serial~=self.serial or not self:isVisible() then return end
        self:cancelTimers()
        self.pending=false
        self:render(data or {error="No server response. Please refresh."})
    end)
end
function ui:refresh()
    self:cancelTimers()
    self.pending=false;self.container:removeAllSubviews();self:text("Checking partners and beds...",25,85,20)
    self:send(self.partner and "inspect" or "list")
end
function ui:render(data)
    self.container:removeAllSubviews()
    local width,height=self.container.size.x,self.container.size.y
    self:button("Refresh",width-140,65,110,function()self:refresh()end)
    if self.partner then self:button("Choose partner",25,65,165,function()self.partner=nil;self:refresh()end) end
    if data.error then self:text(data.error,25,120,19);return end
    if data.rows then
        self:text("Choose a partner for "..data.name,25,108,20)
        local spacing=math.min(48,(height-235)/8)
        for i,row in ipairs(data.rows) do
            local y=145+(i-1)*spacing
            self:button(row.name,25,y,250,function()self.partner=row.id;self:refresh()end)
            local text=row.available and ("Chance: "..row.likelihood.." | Failures: "..row.failures.." / 3") or row.reason
            self:text(text,290,y+4,14)
        end
        self:button("Previous",25,height-65,110,function()self.page=self.page-1;self:refresh()end,self.page==0)
        self:text("Page "..(self.page+1).." / "..math.max(1,math.ceil(data.count/8)),155,height-61,16)
        self:button("Next",300,height-65,110,function()self.page=self.page+1;self:refresh()end,(self.page+1)*8>=data.count)
        if data.count==0 then self:text("No adult partners are available in your tribe.",25,160,18) end
    else
        self:text(data.name and ("Selected partner: "..data.name) or "Pair meeting",25,125,22)
        if data.message then self:text(data.message,25,180,19) end
        if data.busy then
            self:text("Both partners must arrive before the animation starts. Interruptions do not count as failed attempts.",25,245,18)
            self:text("Status updates automatically. You can close this window while they meet.",25,310,17)
            local serial=self.serial
            self.pollTimer=timer:addCallbackTimer(2,function()
                self.pollTimer=nil
                if serial==self.serial and self:isVisible() then self:send("inspect") end
            end)
        else
            self:text(data.available and ("Chance: "..data.likelihood.." ("..math.floor(data.probability*100+0.5).."%)") or "Currently unavailable",25,245,22)
            self:text(data.reason or "Two suitable beds found. Both partners will walk to their sleeping places.",25,290,17)
            self:text("Failed attempts for this pair: "..(data.failures or 0).." / 3",25,355,18)
            self:button("Try for a Baby",25,405,230,function()
                if self.pending then return end
                self.container:removeAllSubviews();self:text("Starting the meeting...",25,100,20);self:send("start")
            end,not data.available)
        end
        self:text("After 3 failures, this pair waits 5 age years. Natural pregnancies remain independent.",25,height-70,16)
    end
end
return ui
