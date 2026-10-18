-- Custom UI lives outside mainThread/ui: Hammerstone 1.8.4 patches every
-- module in that vanilla namespace and rejects files absent from the game.
local mjm = mjrequire "common/mjm"
local vec2, vec3 = mjm.vec2, mjm.vec3
local buttons = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local common = mjrequire "mainThread/ui/uiCommon/uiCommon"
local requests = mjrequire "familyTree/requestScope"
local players = mjrequire "mainThread/playerSapiens"
local ui = {serial = 0, page = 0, history = {}}
local function short(s, n)
    s = s or "Unknown"
    if #s > n then
        local last = n - 3
        while last > 0 do
            local nextByte = string.byte(s, last + 1)
            if not nextByte or nextByte < 128 or nextByte >= 192 then break end
            last = last - 1
        end
        return string.sub(s, 1, last) .. "..."
    end
    return s
end
function ui:text(text, x, y, size)
    local v = TextView.new(self.view)
    v.font = Font(common.fontName, size or 16)
    v.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    v.baseOffset = vec3(x, -(65 + y * 0.86), 2)
    v.color = mj.textColor
    v.text = text
    return v
end
function ui:button(text, x, y, width, fn, disabled, height)
    local v = buttons:create(self.view, vec2(width, (height or 28) * 0.86), buttons.types.standard_10x3)
    v.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
    v.baseOffset = vec3(x, -(65 + y * 0.86), 3)
    buttons:setText(v, text)
    buttons:setClickFunction(v, fn)
    if disabled then buttons:setDisabled(v, true) end
    return v
end
function ui:personButton(row, title, x, y, width, height)
    if row and row.id == self.oldestID then title = "* " .. title end
    self:button(short(title, math.floor((width - 33) / 9)), x, y, width - 33, function()
        if row then self:select(row.id) end
    end, not row or row.status == "unknown" or not row.tribeID, height)
    local live = row and row.status ~= "deceased" and players:getInfo(row.id)
    local zoom = self:button("", x + width - 28, y, 28, function()
        self:visit(row)
    end, not live, height)
    buttons:setIconModel(zoom, "icon_inspect")
end
function ui:visit(row)
    local current=row and row.id and players:getInfo(row.id)
    if not current or row.status=="deceased" then return end
    self:hide()
    local gameUI=mjrequire "mainThread/ui/gameUI"
    local hubUI=mjrequire "mainThread/ui/hubUI"
    gameUI:followObject(current,false,{dismissAnyUI=true,stopWhenClose=true})
    hubUI:setLookAtInfo(current,false,false)
    hubUI:showInspectUI(current,nil,false)
end
function ui:closeTree()
    if self.tree then self.tree:close();self.tree=nil end
end
function ui:openTree(data)
    self.tree=(mjrequire "familyTree/treeView").open(self.view,data.root,{
        family=data,short=short,summary=self.summary,oldestID=self.oldestID,hasHistory=#self.history>0,
        archive=function()self:archive()end,names=function()self:openNames()end,
        home=function()self:home()end,back=function()self:popUI()end,refresh=function()self:request()end,
        focus=function(row)self:select(row.id)end,visit=function(row)self:visit(row)end})
end
function ui:select(id)
    if not id or (id == self.id and not self.listMode) then return end
    self:pushHistory()
    self.id,self.page,self.listMode=id,0,false
    self:request()
end
function ui:pushHistory()
    if not self.id then return end
    table.insert(self.history,{id=self.id,page=self.page,listMode=self.listMode})
    if #self.history>64 then table.remove(self.history,1) end
end
function ui:archive()
    if self.listMode then return end
    self:pushHistory();self.listMode,self.page=true,0;self:request()
end
function ui:openNames()
    requests.cancel(self)
    self.serial=self.serial+1
    self:closeTree()
    if self.settings then self.settings:close() end
    self.view:removeAllSubviews()
    self.settings=(mjrequire "familyTree/settingsUI").open(self.view,function()self:request()end)
end
function ui:request()
    self:closeTree()
    if self.settings then self.settings:close();self.settings=nil end
    self.serial=self.serial+1
    local serial=self.serial
    self.oldestID,self.summary=nil,nil
    self.view:removeAllSubviews()
    self:text("Family Tree - Loading...",25,25,24)
    local request=self.listMode and {action="list",page=self.page} or {action="household",id=self.id}
    requests.call(self,request,function(data)
        if self.hidden or self.serial~=serial then return end
        self:render(data or {error="No server response"})
        if data and data.root then self:requestStats(data,serial,0,{living=0,deceased=0,unknown=0}) end
    end)
end
function ui:requestStats(data, serial, page, totals)
    requests.call(self, {id=data.root.id, action="familySummary", page=page,revision=totals.revision}, function(part)
        if self.hidden or serial ~= self.serial then return end
        if not part or part.error then
            self.summary = {error=true}; self:render(data); return
        end
        totals.revision=part.revision
        if part.pending then self:requestStats(data,serial,page,totals);return end
        for _, key in ipairs({"living", "deceased", "unknown"}) do totals[key] = totals[key] + part[key] end
        local oldest = part.oldest
        if oldest and (not totals.oldest or oldest.age > totals.oldest.age or
            (oldest.age == totals.oldest.age and oldest.id < totals.oldest.id)) then totals.oldest = oldest end
        if part.done then
            totals.unresolved = not part.resolved
            self.summary, self.oldestID = totals, totals.oldest and totals.oldest.id
            self:render(data)
        else self:requestStats(data, serial, page+1, totals) end
    end)
end
function ui:render(data)
    if data.root and not data.error then
        -- Statistics only update the header/marker. Never reset expanded
        -- branches, trace selection, or camera when a late stats page arrives.
        if self.tree then self.tree:setSummary(self.summary,self.oldestID) else self:openTree(data) end
        return
    end
    self:closeTree()
    self.view:removeAllSubviews()
    local width=self.view.size.x
    self:button("Starting Sapien",20,10,150,function()self:home()end,self.id==self.originID and not self.listMode)
    self:button("Archive",185,10,110,function()self:archive()end,self.listMode)
    self:button("Back",310,10,100,function()self:popUI()end,#self.history==0)
    self:button("Names",425,10,110,function()self:openNames()end)
    self:button("Refresh",width-130,10,110,function()self:request()end)
    if data.error then self:text(data.error,25,85,20);return end
    self:text("Tribe archive - including deceased",25,52,20)
    local colWidth=(width-60)/2
    for i,row in ipairs(data.rows or {}) do
        local index=i-1
        local label=row.name or ("Unknown "..(row.id or ""))
        if row.status=="deceased" then label=label.." [deceased]" end
        if row.status=="removed" then label=label.." [whereabouts unknown]" end
        self:personButton(row,label,20+math.floor(index/16)*(colWidth+20),86+(index%16)*29,colWidth)
    end
    self:paging(data.count or 0,570)
end
function ui:paging(count, y)
    self:button("Previous", 20, y, 110, function()
        self.page = math.max(0, self.page - 1)
        self:request()
    end, self.page == 0)
    self:text("Page " .. (self.page + 1) .. " / " .. math.max(1, math.ceil(count / 32)), 145, y + 6, 16)
    self:button("Next", 290, y, 110, function()
        self.page = self.page + 1
        self:request()
    end, (self.page + 1) * 32 >= count)
end
function ui:init(view)
    requests.cancel(self)
    self:closeTree()
    if self.settings then self.settings:close();self.settings=nil end
    self.serial=(self.serial or 0)+1
    self.view,self.id,self.hidden=view,nil,true
    self.listMode,self.page,self.history=false,0,{}
end
function ui:show(sapien)
    self.hidden=false
    self.originID=sapien.uniqueID
    self:home()
end
function ui:home()
    self.id,self.page,self.listMode,self.history=self.originID,0,false,{}
    self:request()
end
function ui:hide()
    requests.cancel(self)
    self:closeTree()
    if self.settings then self.settings:close();self.settings=nil end
    self.hidden=true;self.serial=self.serial+1
end
function ui:popUI()
    if self.settings then self:request();return true end
    local prev=table.remove(self.history)
    if prev then
        self.id,self.page,self.listMode=prev.id,prev.page,prev.listMode
        self:request();return true
    end
    return false
end
return ui
