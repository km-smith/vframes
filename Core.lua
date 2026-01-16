-- vframes: A custom party/raid frame addon with Edit Mode integration
-- This is a learning shell for WoW addon development

local addonName, addon = ...

-- Saved variables (will be loaded from SavedVariables)
vframesDB = vframesDB or {}

---------------------------------------------------------------------------
-- Main Frame Setup
---------------------------------------------------------------------------

-- Edit Mode system settings definition
local SETTING_GROWTH_DIRECTION = 1
local SETTING_FRAME_WIDTH = 2
local SETTING_FRAME_HEIGHT = 3
local SETTING_FRAME_SPACING = 4

local MainFrame = CreateFrame("Frame", "vframesFrame", UIParent, "BackdropTemplate")
MainFrame:SetSize(200, 150)
MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Initialize settings early (before health frames)
MainFrame.settings = {
    [SETTING_GROWTH_DIRECTION] = 1, -- 1 = Horizontal, 2 = Vertical
    [SETTING_FRAME_WIDTH] = 120,
    [SETTING_FRAME_HEIGHT] = 40,
    [SETTING_FRAME_SPACING] = 2,
}

-- Visual styling
MainFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
})
MainFrame:SetBackdropColor(0.1, 0.3, 0.6, 0.1)  -- Very transparent blue overlay
MainFrame:SetBackdropBorderColor(0.3, 0.6, 0.9, 0.3)  -- Semi-transparent blue border

-- Title text
local title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", MainFrame, "TOP", 0, -10)
title:SetText("vframes")
title:Show()

-- Status text (shows current state)
local statusText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("CENTER", MainFrame, "CENTER", 0, 0)
statusText:SetText("Edit Mode: Disabled")
statusText:Hide()

-- Instruction text
local instructionText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
instructionText:SetPoint("BOTTOM", MainFrame, "BOTTOM", 0, 10)
instructionText:SetTextColor(0.7, 0.7, 0.7, 1)
instructionText:SetText("Open Edit Mode to configure")
instructionText:Hide()

---------------------------------------------------------------------------
-- Health Frames System
---------------------------------------------------------------------------

-- Table to store all health frames
local healthFrames = {}

-- Create a single health frame for a unit
local function CreateHealthFrame(unit)
    local frame = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
    frame:SetSize(120, 40)

    -- Visual styling
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, 0.7)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Health bar (using StatusBar to support secret values in 12.0.0+)
    local healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetAllPoints(frame)
    healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    healthBar:SetStatusBarColor(0, 0.8, 0, 0.8)
    healthBar:SetMinMaxValues(0, 100)
    healthBar:SetValue(100)
    frame.healthBar = healthBar

    -- Health bar background
    local healthBg = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBg:SetAllPoints(healthBar)
    healthBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    -- Name text
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOP", frame, "TOP", 0, -5)
    nameText:SetTextColor(1, 1, 1, 1)
    frame.nameText = nameText

    -- Health text
    local healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
    healthText:SetTextColor(1, 1, 1, 1)
    frame.healthText = healthText

    frame.unit = unit
    frame:Hide()

    return frame
end

-- Update a single health frame's data
local function UpdateHealthFrame(frame)
    if not frame or not frame.unit then return end

    local unit = frame.unit

    -- Check if unit exists
    if not UnitExists(unit) then
        frame:Hide()
        return
    end

    frame:Show()

    -- Update name
    local name = UnitName(unit)
    frame.nameText:SetText(name or "Unknown")

    -- Update health (12.0.0+ secret values support)
    -- StatusBar can accept secret values directly via SetValue/SetMinMaxValues
    local health = UnitHealth(unit)
    local maxHealth = UnitHealthMax(unit)

    -- Set health bar values (StatusBar accepts secret values)
    frame.healthBar:SetMinMaxValues(0, maxHealth)
    frame.healthBar:SetValue(health)

    -- Calculate percentage for display and color (using GetValue which returns non-secret)
    -- When we read back from StatusBar, it's no longer secret
    local currentValue = frame.healthBar:GetValue()
    local minValue, maxValue = frame.healthBar:GetMinMaxValues()
    local healthPercent = (maxValue > 0) and (currentValue / maxValue) or 0

    -- Update health text (now using non-secret values from StatusBar)
    frame.healthText:SetText(string.format("%.0f%%", healthPercent * 100))

    -- Color health bar based on percentage
    if healthPercent > 0.5 then
        frame.healthBar:SetStatusBarColor(0, 0.8, 0, 0.8) -- Green
    elseif healthPercent > 0.25 then
        frame.healthBar:SetStatusBarColor(0.8, 0.8, 0, 0.8) -- Yellow
    else
        frame.healthBar:SetStatusBarColor(0.8, 0, 0, 0.8) -- Red
    end
end

-- Update layout based on growth direction
function UpdateHealthFramesLayout()
    local settings = MainFrame.settings
    local growthDirection = settings[SETTING_GROWTH_DIRECTION] or 1
    local spacing = settings[SETTING_FRAME_SPACING] or 2

    local visibleFrames = {}
    for _, frame in ipairs(healthFrames) do
        if frame:IsShown() then
            table.insert(visibleFrames, frame)
        end
    end

    for i, frame in ipairs(visibleFrames) do
        frame:ClearAllPoints()

        if i == 1 then
            frame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 5, -5)
        else
            local prevFrame = visibleFrames[i - 1]
            if growthDirection == 1 then -- Horizontal
                frame:SetPoint("LEFT", prevFrame, "RIGHT", spacing, 0)
            else -- Vertical
                frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, -spacing)
            end
        end
    end

    -- Resize main frame to fit all health frames
    if #visibleFrames > 0 then
        local frameWidth = visibleFrames[1]:GetWidth()
        local frameHeight = visibleFrames[1]:GetHeight()

        if growthDirection == 1 then -- Horizontal
            MainFrame:SetSize((frameWidth + spacing) * #visibleFrames + 5, frameHeight + 10)
        else -- Vertical
            MainFrame:SetSize(frameWidth + 10, (frameHeight + spacing) * #visibleFrames + 5)
        end
    end
end

-- Update all visible health frames
local function UpdateAllHealthFrames()
    -- Update player frame
    if healthFrames[1] then
        healthFrames[1].unit = "player"
        UpdateHealthFrame(healthFrames[1])
    end

    -- Update party frames
    local numPartyMembers = GetNumSubgroupMembers()
    for i = 1, 4 do
        local frameIndex = i + 1
        if i <= numPartyMembers then
            healthFrames[frameIndex].unit = "party" .. i
            UpdateHealthFrame(healthFrames[frameIndex])
        else
            healthFrames[frameIndex]:Hide()
        end
    end

    UpdateHealthFramesLayout()
end

-- Initialize health frames
local function InitializeHealthFrames()
    -- Create frames for player + 4 party members
    for i = 1, 5 do
        healthFrames[i] = CreateHealthFrame(i == 1 and "player" or ("party" .. (i - 1)))
    end

    -- Initial update
    UpdateAllHealthFrames()

    -- Set up update timer
    C_Timer.NewTicker(0.1, UpdateAllHealthFrames)
end

---------------------------------------------------------------------------
-- Edit Mode Integration
---------------------------------------------------------------------------

local function GetSettingsDialogOptions()
    return {
        {
            setting = SETTING_GROWTH_DIRECTION,
            name = "Growth Direction",
            type = Enum.EditModeSettingDisplayType.Dropdown,
            options = {
                {value = 1, text = "Horizontal"},
                {value = 2, text = "Vertical"},
            },
        },
    }
end

-- Initialize Edit Mode system
local function SetupEditMode()
    -- Check if Edit Mode API is available
    if not EditModeManagerFrame then
        print("|cffff6600vframes:|r Edit Mode API not available")
        return
    end

    -- Make frame movable in Edit Mode
    MainFrame:SetMovable(true)
    MainFrame:SetClampedToScreen(true)

    -- Register for Edit Mode
    MainFrame.system = "vframes" -- Custom system identifier

    -- Required Edit Mode methods
    MainFrame.GetSettingsDialogOptions = GetSettingsDialogOptions

    MainFrame.GetSettingValue = function(self, setting)
        return self.settings[setting]
    end

    MainFrame.SetSettingValue = function(self, setting, value)
        self.settings[setting] = value
        if setting == SETTING_GROWTH_DIRECTION then
            print("|cff00ff00vframes:|r Growth Direction set to:", value == 1 and "Horizontal" or "Vertical")
            UpdateHealthFramesLayout()
        end
    end

    MainFrame.GetSettingValueBool = function(self, setting)
        return self.settings[setting] == true
    end

    -- Selection highlight frame
    MainFrame.Selection = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
    MainFrame.Selection:SetAllPoints(MainFrame)
    MainFrame.Selection:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
    })
    MainFrame.Selection:SetBackdropBorderColor(0.4, 0.8, 1, 1) -- Bright blue highlight
    MainFrame.Selection:Hide()

    MainFrame.SetSelectionShown = function(self, shown)
        if shown then
            self.Selection:Show()
        else
            self.Selection:Hide()
        end
    end

    MainFrame.IsInDefaultPosition = function(self)
        return false
    end

    -- Drag handling for Edit Mode with click detection
    local isDragging = false
    local mouseDownX, mouseDownY = 0, 0

    MainFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and EditModeManagerFrame:IsEditModeActive() then
            isDragging = false
            mouseDownX, mouseDownY = GetCursorPosition()
            self:StartMoving()
        end
    end)

    MainFrame:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        self:StopMovingOrSizing()

        -- Check if this was a click (minimal movement) vs a drag
        local mouseUpX, mouseUpY = GetCursorPosition()
        local distance = math.sqrt((mouseUpX - mouseDownX)^2 + (mouseUpY - mouseDownY)^2)

        if distance < 5 and EditModeManagerFrame:IsEditModeActive() then
            -- This was a click, toggle selection
            local isSelected = MainFrame.Selection:IsShown()
            MainFrame:SetSelectionShown(not isSelected)

            if not isSelected then
                print("|cff00ff00vframes:|r Frame selected! Settings would appear here.")
                print("|cff00ff00vframes:|r Dummy Option is currently:", MainFrame.settings[SETTING_DUMMY_OPTION] and "ON" or "OFF")
            end
        else
            -- This was a drag, save position
            local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
            vframesDB.position = {
                point = point,
                relativePoint = relativePoint,
                x = xOfs,
                y = yOfs,
            }
        end
    end)

    -- Register click handler for Edit Mode selection
    MainFrame:EnableMouse(true)
    MainFrame:SetScript("OnEnter", function(self)
        if EditModeManagerFrame:IsEditModeActive() then
            self:SetBackdropBorderColor(0.4, 0.8, 1, 1)  -- Bright blue on hover
        end
    end)

    MainFrame:SetScript("OnLeave", function(self)
        if not MainFrame.Selection:IsShown() then
            self:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)  -- Return to blue border
        end
    end)

    -- Hook into Edit Mode state changes
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
        MainFrame:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)  -- Blue border in edit mode
    end)

    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
        MainFrame:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)  -- Blue border when exiting
        MainFrame.Selection:Hide()
    end)

    print("|cff00ff00vframes:|r Edit Mode integration loaded")
end

---------------------------------------------------------------------------
-- Position Restore
---------------------------------------------------------------------------

local function RestorePosition()
    if vframesDB.position then
        local pos = vframesDB.position
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

local function OnAddonLoaded(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end

    -- Restore saved position
    RestorePosition()

    -- Initialize health frames
    InitializeHealthFrames()

    -- Setup Edit Mode after a short delay to ensure all systems are ready
    C_Timer.After(1, SetupEditMode)

    print("|cff00ff00vframes|r loaded. Health frames active. Open Edit Mode (Esc > Edit Mode) to configure.")
end

MainFrame:RegisterEvent("ADDON_LOADED")
MainFrame:SetScript("OnEvent", OnAddonLoaded)

-- Expose addon table for debugging
addon.MainFrame = MainFrame
_G["vframes"] = addon
