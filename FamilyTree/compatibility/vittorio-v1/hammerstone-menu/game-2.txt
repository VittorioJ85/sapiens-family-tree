local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local model = mjrequire "common/model"
local material = mjrequire "common/material"
--local keyMapping = mjrequire "mainThread/keyMapping"
local locale = mjrequire "common/locale"

local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"

local buildCollection = mjrequire "mainThread/ui/manageUI/buildCollection"
local tribeCollection = mjrequire "mainThread/ui/manageUI/tribeCollection"

local optionsUI = mjrequire "mainThread/ui/manageUI/optionsUI"

local manageButtonsUI = mjrequire "mainThread/ui/manageButtonsUI"

local manageUI = {}

local hubUI = nil

--local world = nil

manageUI.mainView = nil

local modeTypes = mj:enum {
    "build",
    "tribe",
    "options",
}

manageUI.modeTypes = modeTypes

manageUI.modeInfos = {
    [modeTypes.build] = {
        title = locale:get("manage_build"),
        icon = "icon_hammer",
    },
    [modeTypes.tribe] = {
        title = locale:get("manage_tribe"),
        icon = "icon_tribe2",
    },
    [modeTypes.options] = {
        title = locale:get("settings_options"),
        icon = "icon_settings",
    },
}

--local tabButtonSize = 80.0
local backgroundSize = vec2(1140, 640)
local iconHalfSize = 14
local iconPadding = 6
--local innerViewPadding = 10

manageUI.mainContentView = nil
manageUI.titleView = nil
manageUI.titleTextView = nil
manageUI.titleIcon = nil

manageUI.currentModeIndex = nil

manageUI.uiObjectsByModeType = {
    [modeTypes.build] = buildCollection,
    [modeTypes.tribe] = tribeCollection,
    [modeTypes.options] = optionsUI,
}


local function setTitleTextAndIcon(text, iconModelName)
    manageUI.titleTextView:setText(text, material.types.standardText.index)
    manageUI.titleIcon:setModel(model:modelIndexForName(iconModelName))
    manageUI.titleView.size = vec2(manageUI.titleTextView.size.x + iconHalfSize + iconHalfSize + iconPadding, manageUI.titleView.size.y)
end

local function updateCurrentView(contextOrNil)

    local titleString = nil
    if manageUI.currentModeIndex == modeTypes.options then
        titleString = optionsUI:getTitle()
    end
    if not titleString then
        titleString = manageUI.modeInfos[manageUI.currentModeIndex].title
    end

    setTitleTextAndIcon(titleString, manageUI.modeInfos[manageUI.currentModeIndex].icon)

    --manageUI.uiObjectsByModeType[manageUI.currentModeIndex]:update()
    manageUI.uiObjectsByModeType[manageUI.currentModeIndex]:show(contextOrNil)
end

function manageUI:getCurrentModeIndex()
    return manageUI.currentModeIndex
end

local function switchTabs(modeIndex, contextOrNil)
    if manageUI.currentModeIndex ~= modeIndex then
        if manageUI.currentModeIndex then
            local currentInfo = manageUI.modeInfos[manageUI.currentModeIndex]
            currentInfo.contentView.hidden = true

            manageUI.uiObjectsByModeType[manageUI.currentModeIndex]:hide()
        end

        manageUI.currentModeIndex = modeIndex


        local currentInfo = manageUI.modeInfos[manageUI.currentModeIndex]
        currentInfo.contentView.hidden = false
        
        if not manageUI:hidden() then
            manageButtonsUI:setSelectedButton(modeIndex)
        end

        if currentInfo.isCollection then
            manageUI.titleView.hidden = true
        else
            manageUI.titleView.hidden = false
        end

        --uiStandardButton:setDisabled(currentInfo.button, true)
        --uiStandardButton:setSelected(currentInfo.button, true)
        
        updateCurrentView(contextOrNil)
        return true
    end
    return false
end

--[[local function selectNextTab()
    local modeIndex = manageUI.currentModeIndex + 1
    if modeIndex > #modeTypes then
        modeIndex = 1
    end
    switchTabs(modeIndex)
end]]


local keyMap = {
    --[[[keyMapping:getMappingIndex("game", "nextTab")] = function(isDown, modKey) nextTab doesn't actually exist, not sure what to do about this
        if isDown then 
            selectNextTab()
        end 
        return true 
    end,]]
}

local function keyChanged(isDown, code, modKey, isRepeat)
    if keyMap[code]  then
		return keyMap[code](isDown, isRepeat)
	end
end

function manageUI:init(gameUI, controller, hubUI_, world_, logicInterface)

    --world = world_

    hubUI = hubUI_

    manageUI.mainView = View.new(gameUI.view)
    manageUI.mainView.hidden = true
    manageUI.mainView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    manageUI.mainView.size = backgroundSize

    manageUI.mainView.keyChanged = keyChanged
    
    manageUI.mainContentView = ModelView.new(manageUI.mainView)
    --manageUI.mainContentView:setRenderTargetBacked(true)
    manageUI.mainContentView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))
    local scaleToUse = backgroundSize.x * 0.5
    manageUI.mainContentView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
    manageUI.mainContentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    manageUI.mainContentView.size = backgroundSize

    manageUI.titleView = View.new(manageUI.mainContentView)
    manageUI.titleView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    manageUI.titleView.baseOffset = vec3(0,-10, 0)
    manageUI.titleView.size = vec2(200, 32.0)
    
    manageUI.titleIcon = ModelView.new(manageUI.titleView)
    manageUI.titleIcon.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
    --icon.baseOffset = vec3(4, 0, 1)
    manageUI.titleIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    manageUI.titleIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0

    manageUI.titleTextView = ModelTextView.new(manageUI.titleView)
    manageUI.titleTextView.font = Font(uiCommon.titleFontName, 36)
    manageUI.titleTextView.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)
    manageUI.titleTextView.relativeView = manageUI.titleIcon
    manageUI.titleTextView.baseOffset = vec3(iconPadding, 0, 0)

    --[[local closeButton = uiStandardButton:create(manageUI.mainContentView, vec2(50.0, 55.0), uiStandardButton.types.tab_1x1, nil)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    local zOffset = -2.0
    closeButton.baseOffset = vec3(10, 0, zOffset)
    uiStandardButton:setText(closeButton, "X")
    uiStandardButton:setClickFunction(closeButton, function()
        manageUI:hide()
    end)]]

    
    
    local closeButton = uiStandardButton:create(manageUI.mainContentView, vec2(50,50), uiStandardButton.types.markerLike)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    closeButton.baseOffset = vec3(30, -20, 0)
    uiStandardButton:setIconModel(closeButton, "icon_cross")
    uiStandardButton:setClickFunction(closeButton, function()
        manageUI:hide()
    end)

    
    local belowTopPadding = 40

    
    --mj:log("manageUI:init manageUI.mainContentView.size.y:", manageUI.mainContentView.size.y, " manageUI.titleTextView.size.y:", manageUI.titleTextView.size.y, "manageUI.titleTextView.baseOffset.y:", manageUI.titleTextView.baseOffset.y )

    local buildContentView = View.new(manageUI.mainContentView)
    buildContentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    buildContentView.size = vec2(manageUI.mainContentView.size.x, manageUI.mainContentView.size.y)
    buildContentView.hidden = true
    buildCollection:init(gameUI, world_, manageUI, buildContentView)

    local tribeContentView = View.new(manageUI.mainContentView)
    tribeContentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    tribeContentView.size = vec2(manageUI.mainContentView.size.x, manageUI.mainContentView.size.y)
    tribeContentView.hidden = true
    tribeCollection:init(gameUI, world_, manageUI, hubUI, tribeContentView, logicInterface)
    
    local optionsContentView = View.new(manageUI.mainContentView)
    optionsContentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionBottom)
    optionsContentView.size = vec2(manageUI.mainContentView.size.x, manageUI.mainContentView.size.y - belowTopPadding)
    optionsContentView.hidden = true
    optionsUI:init(gameUI, controller, world_, manageUI, optionsContentView)

    manageUI.modeInfos[modeTypes.build].contentView = buildContentView
    manageUI.modeInfos[modeTypes.build].isCollection = true
    manageUI.modeInfos[modeTypes.tribe].contentView = tribeContentView
    manageUI.modeInfos[modeTypes.tribe].isCollection = true

    manageUI.modeInfos[modeTypes.options].contentView = optionsContentView

    --switchTabs(modeTypes.build, nil)


    manageButtonsUI:updateHiddenState()
end

function manageUI:show(modeIndexOrNil, contextOrNil)
    --mj:log(debug.traceback())
    hubUI:setManageUIVisible(true)
    local updatedOnSwitch = false
    if modeIndexOrNil then
        updatedOnSwitch = switchTabs(modeIndexOrNil, contextOrNil)
    --elseif manageUI.currentModeIndex == modeTypes.options then
        --updatedOnSwitch = switchTabs(modeTypes.build, contextOrNil)
    elseif (not manageUI.currentModeIndex) then
        updatedOnSwitch = switchTabs(modeTypes.build, nil)
    end
    --[[for k,info in pairs(manageUI.modeInfos) do
        local button = info.button
        uiStandardButton:resetAnimationState(button)
    end]]
    manageUI.mainView.hidden = false
    if not updatedOnSwitch then
        updateCurrentView(contextOrNil)
    end
    manageButtonsUI:updateHiddenState()
    manageButtonsUI:setSelectedButton(manageUI.currentModeIndex)
end

function manageUI:showTribeSelectionSettingsMenu()
    local updatedOnSwitch = switchTabs(modeTypes.options, nil)
    manageUI.mainView.hidden = false
    if not updatedOnSwitch then
        updateCurrentView(nil)
    end
end

function manageUI:subTabSelectionShortcut(selectionIndex)
    mj:log("manageUI:subTabSelectionShortcut:", selectionIndex)
    if manageUI.currentModeIndex then
        local currentInfo = manageUI.modeInfos[manageUI.currentModeIndex]
        if currentInfo.isCollection then
            manageUI.uiObjectsByModeType[manageUI.currentModeIndex]:tabSelectionShortcut(selectionIndex)
        end
    end 
end

function manageUI:hide()
    if not manageUI.mainView.hidden then
        if manageUI.currentModeIndex then
            manageUI.uiObjectsByModeType[manageUI.currentModeIndex]:hide()
        end
        manageUI.mainView.hidden = true
        manageButtonsUI:setSelectedButton(nil)
        manageButtonsUI:updateHiddenState()
        hubUI:setManageUIVisible(false)
    end
end

function manageUI:popUI()
    if not manageUI.mainView.hidden and manageUI.currentModeIndex then
        if not manageUI.uiObjectsByModeType[manageUI.currentModeIndex]:popUI() then
            manageUI:hide()
            return false
        end
        return true
    end
    return false
end

function manageUI:changeTitle(newTitle, icon)
    setTitleTextAndIcon(newTitle, icon)
end

--[[function manageUI:resetTitle()
    local currentInfo = manageUI.modeInfos[manageUI.currentModeIndex]
    setTitleTextAndIcon(currentInfo.title, currentInfo.icon)
end]]

function manageUI:uiIsHidden(uiObject)
    --mj:log("manageUI:uiIsHidden:", manageUI.mainView.hidden)
    if manageUI.mainView.hidden or manageUI.currentModeIndex == nil then
        return true
    end

    local currentUIObject = manageUI.uiObjectsByModeType[manageUI.currentModeIndex]
    --mj:log("manageUI:uiIsHidden currentUIObject:", currentUIObject, " uiObject:", uiObject)
    if currentUIObject == uiObject then
        return false
    end

    if currentUIObject.modeTypes then --is collection
        return currentUIObject:uiIsHidden(uiObject)
    end
    
    return true
end

function manageUI:getCurrentModeIndex()
    return manageUI.currentModeIndex
end

function manageUI:hidden()
    return (manageUI.mainView.hidden)
end

return manageUI