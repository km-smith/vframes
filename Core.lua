-- vframes: A custom party/raid frame addon with Edit Mode integration
-- This is a learning shell for WoW addon development

local addonName, addon = ...

-- Saved variables (will be loaded from SavedVariables)
vframesDB = vframesDB or {}

---------------------------------------------------------------------------
-- Main Frame Setup
---------------------------------------------------------------------------

local MainFrame = CreateFrame("Frame", "vframesFrame", UIParent, "BackdropTemplate")
MainFrame:SetSize(200, 150)
MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Visual styling
MainFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
})
MainFrame:SetBackdropColor(0.1, 0.3, 0.6, 0.5)  -- Blue overlay
MainFrame:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)  -- Blue border

-- Title text
local title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", MainFrame, "TOP", 0, -10)
title:SetText("vframes")

-- Status text (shows current state)
local statusText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("CENTER", MainFrame, "CENTER", 0, 0)
statusText:SetText("Edit Mode: Disabled")

-- Instruction text
local instructionText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
instructionText:SetPoint("BOTTOM", MainFrame, "BOTTOM", 0, 10)
instructionText:SetTextColor(0.7, 0.7, 0.7, 1)
instructionText:SetText("Open Edit Mode to configure")

---------------------------------------------------------------------------
-- Edit Mode Integration
---------------------------------------------------------------------------

-- Edit Mode system settings definition
local SETTING_DUMMY_OPTION = 1

local function GetSettingsDialogOptions()
    return {
        {
            setting = SETTING_DUMMY_OPTION,
            name = "Dummy Option",
            type = Enum.EditModeSettingDisplayType.Checkbox,
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

    -- Settings storage
    MainFrame.settings = {
        [SETTING_DUMMY_OPTION] = false,
    }

    -- Required Edit Mode methods
    MainFrame.GetSettingsDialogOptions = GetSettingsDialogOptions

    MainFrame.GetSettingValue = function(self, setting)
        return self.settings[setting]
    end

    MainFrame.SetSettingValue = function(self, setting, value)
        self.settings[setting] = value
        if setting == SETTING_DUMMY_OPTION then
            print("|cff00ff00vframes:|r Dummy Option set to:", value and "ON" or "OFF")
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
        statusText:SetText("Edit Mode: |cff00ff00ACTIVE|r")
        statusText:SetTextColor(0.3, 1, 0.3, 1)
        MainFrame:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)  -- Blue border in edit mode
    end)

    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
        statusText:SetText("Edit Mode: Disabled")
        statusText:SetTextColor(1, 1, 1, 1)
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

    -- Setup Edit Mode after a short delay to ensure all systems are ready
    C_Timer.After(1, SetupEditMode)

    print("|cff00ff00vframes|r loaded. Open Edit Mode (Esc > Edit Mode) to configure.")
end

MainFrame:RegisterEvent("ADDON_LOADED")
MainFrame:SetScript("OnEvent", OnAddonLoaded)

-- Expose addon table for debugging
addon.MainFrame = MainFrame
_G["vframes"] = addon
