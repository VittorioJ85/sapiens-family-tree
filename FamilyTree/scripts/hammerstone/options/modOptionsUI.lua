local mod={loadOrder=20}
function mod:onload(ui)
    local create=ui.createControls
    function ui:createControls(parent,popovers,key,options,values)
        -- Hammerstone builds all mod panels eagerly and keeps them alive when
        -- switching tabs. Another mod's createControls is not a close event.
        if key ~= "familyTree" then return create(self,parent,popovers,key,options,values) end
        -- Cancel callbacks only when replacing our own controls (e.g. Reset).
        if self.familyTreeSettings then self.familyTreeSettings:close(); self.familyTreeSettings=nil end
        self.familyTreeSettings=(mjrequire "familyTree/settingsUI").open(parent)
    end
    local show=ui.show
    function ui:show(...)
        show(self,...)
        if self.familyTreeSettings then self.familyTreeSettings:load() end
    end
    local hide=ui.hide
    function ui:hide(...)
        if self.familyTreeSettings then self.familyTreeSettings:close() end
        return hide(self,...)
    end
end
return mod
