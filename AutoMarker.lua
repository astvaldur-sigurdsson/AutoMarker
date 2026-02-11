-- AutoMarker: Automatically marks mobs in combat with mana or cast bars
local addonName, addon = ...

-- Raid target marks (1-8)
local MARKS = {
    SKULL = 8,
    CROSS = 7,
    SQUARE = 6,
    MOON = 5,
    TRIANGLE = 4,
    DIAMOND = 3,
    CIRCLE = 2,
    STAR = 1
}

-- Priority order for marking (skull for casters/mana users)
local MARK_PRIORITY = {
    MARKS.SKULL,
    MARKS.CROSS,
    MARKS.DIAMOND,
    MARKS.SQUARE,
    MARKS.MOON,
    MARKS.TRIANGLE,
    MARKS.CIRCLE,
    MARKS.STAR
}

-- Track which mobs we've already marked
local markedUnits = {}
local currentMarkIndex = 1
local scanTicker = nil

-- Core addon object
local AutoMarker = CreateFrame("Frame")

-- Default settings
AutoMarkerDB = AutoMarkerDB or {
    enabled = true,
    enabledSolo = false,
    enabledGroup = true,
    enabledRaid = true,
    markCasters = true,
    markManaUsers = true,
    debug = false
}

-- Debug print function
local function DebugPrint(msg)
    if AutoMarkerDB.debug then
        print("|cFF00FF00[AutoMarker]|r " .. msg)
    end
end

-- Create settings panel
function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "AutoMarkerSettingsPanel", UIParent)
    panel.name = "AutoMarker"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("AutoMarker Settings")
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Automatically marks mobs in combat with mana or cast bars")
    
    -- Master enable checkbox
    local enableCheck = CreateFrame("CheckButton", "AutoMarkerEnableCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    enableCheck.Text:SetText("Enable AutoMarker")
    enableCheck:SetChecked(AutoMarkerDB.enabled)
    enableCheck:SetScript("OnClick", function(self)
        AutoMarkerDB.enabled = self:GetChecked()
        print("|cFF00FF00AutoMarker|r " .. (AutoMarkerDB.enabled and "enabled" or "disabled"))
    end)
    
    -- Group type header
    local groupHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    groupHeader:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -20)
    groupHeader:SetText("Enable for:")
    
    -- Solo checkbox
    local soloCheck = CreateFrame("CheckButton", "AutoMarkerSoloCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    soloCheck:SetPoint("TOPLEFT", groupHeader, "BOTTOMLEFT", 16, -8)
    soloCheck.Text:SetText("Solo play")
    soloCheck:SetChecked(AutoMarkerDB.enabledSolo)
    soloCheck:SetScript("OnClick", function(self)
        AutoMarkerDB.enabledSolo = self:GetChecked()
    end)
    
    -- Group checkbox
    local groupCheck = CreateFrame("CheckButton", "AutoMarkerGroupCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    groupCheck:SetPoint("TOPLEFT", soloCheck, "BOTTOMLEFT", 0, -8)
    groupCheck.Text:SetText("Party (5-player dungeons)")
    groupCheck:SetChecked(AutoMarkerDB.enabledGroup)
    groupCheck:SetScript("OnClick", function(self)
        AutoMarkerDB.enabledGroup = self:GetChecked()
    end)
    
    -- Raid checkbox
    local raidCheck = CreateFrame("CheckButton", "AutoMarkerRaidCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    raidCheck:SetPoint("TOPLEFT", groupCheck, "BOTTOMLEFT", 0, -8)
    raidCheck.Text:SetText("Raid (requires lead/assist)")
    raidCheck:SetChecked(AutoMarkerDB.enabledRaid)
    raidCheck:SetScript("OnClick", function(self)
        AutoMarkerDB.enabledRaid = self:GetChecked()
    end)
    
    -- Detection options header
    local detectHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detectHeader:SetPoint("TOPLEFT", raidCheck, "BOTTOMLEFT", -16, -20)
    detectHeader:SetText("Mark mobs that have:")
    
    -- Mana checkbox
    local manaCheck = CreateFrame("CheckButton", "AutoMarkerManaCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    manaCheck:SetPoint("TOPLEFT", detectHeader, "BOTTOMLEFT", 16, -8)
    manaCheck.Text:SetText("Mana bars")
    manaCheck:SetChecked(AutoMarkerDB.markManaUsers)
    manaCheck:SetScript("OnClick", function(self)
        AutoMarkerDB.markManaUsers = self:GetChecked()
    end)
    
    -- Casting checkbox
    local castCheck = CreateFrame("CheckButton", "AutoMarkerCastCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    castCheck:SetPoint("TOPLEFT", manaCheck, "BOTTOMLEFT", 0, -8)
    castCheck.Text:SetText("Cast/Channel bars")
    castCheck:SetChecked(AutoMarkerDB.markCasters)
    castCheck:SetScript("OnClick", function(self)
        AutoMarkerDB.markCasters = self:GetChecked()
    end)
    
    -- Debug checkbox
    local debugCheck = CreateFrame("CheckButton", "AutoMarkerDebugCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", castCheck, "BOTTOMLEFT", 0, -20)
    debugCheck.Text:SetText("Debug mode (show detailed messages)")
    debugCheck:SetChecked(AutoMarkerDB.debug)
    debugCheck:SetScript("OnClick", function(self)
        AutoMarkerDB.debug = self:GetChecked()
    end)
    
    -- Register with interface options
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- WoW 10.0+ API
        local category = Settings.RegisterCanvasLayoutCategory(panel, "AutoMarker")
        Settings.RegisterAddOnCategory(category)
    else
        -- Legacy API
        InterfaceOptions_AddCategory(panel)
    end
end

-- Check if player is in a group or raid
local function IsInGroupOrRaid()
    return IsInGroup() or IsInRaid()
end

-- Check if player can set raid targets
local function CanSetRaidTargets()
    if not IsInGroupOrRaid() then
        return true -- Can mark when solo
    end
    
    if IsInRaid() then
        -- In raid, need to be leader or assistant
        local isLeader = UnitIsGroupLeader("player")
        local isAssist = UnitIsGroupAssistant("player")
        return isLeader or isAssist
    else
        -- In party, anyone can mark
        return true
    end
end

-- Check if a unit has mana
local function HasMana(unit)
    if not UnitExists(unit) then return false end
    
    local powerType = UnitPowerType(unit)
    -- 0 = Mana
    if powerType == 0 then
        local maxPower = UnitPowerMax(unit, 0)
        return maxPower > 0
    end
    return false
end

-- Check if a unit is casting
local function IsCasting(unit)
    if not UnitExists(unit) then return false end
    
    local name = UnitCastingInfo(unit)
    local channelName = UnitChannelInfo(unit)
    
    return name ~= nil or channelName ~= nil
end

-- Get next available mark
local function GetNextAvailableMark()
    -- Check which marks are already in use
    local usedMarks = {}
    
    -- Check raid/party members' targets
    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i .. "target"
            if UnitExists(unit) then
                local mark = GetRaidTargetIndex(unit)
                if mark then
                    usedMarks[mark] = true
                end
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i .. "target"
            if UnitExists(unit) then
                local mark = GetRaidTargetIndex(unit)
                if mark then
                    usedMarks[mark] = true
                end
            end
        end
    end
    
    -- Check player target
    if UnitExists("target") then
        local mark = GetRaidTargetIndex("target")
        if mark then
            usedMarks[mark] = true
        end
    end
    
    -- Return first unused mark from priority list
    for _, markNum in ipairs(MARK_PRIORITY) do
        if not usedMarks[markNum] then
            return markNum
        end
    end
    
    return nil
end

-- Check if unit should be marked
local function ShouldMarkUnit(unit)
    if not UnitExists(unit) then return false end
    if not UnitCanAttack("player", unit) then return false end
    if UnitIsDead(unit) then return false end
    if not UnitAffectingCombat(unit) then return false end
    
    -- Check if already marked
    if GetRaidTargetIndex(unit) then
        return false
    end
    
    -- Check if unit has mana
    if AutoMarkerDB.markManaUsers and HasMana(unit) then
        DebugPrint("Found unit with mana: " .. (UnitName(unit) or "Unknown"))
        return true
    end
    
    -- Check if unit is casting
    if AutoMarkerDB.markCasters and IsCasting(unit) then
        DebugPrint("Found casting unit: " .. (UnitName(unit) or "Unknown"))
        return true
    end
    
    return false
end

-- Try to mark a unit
local function TryMarkUnit(unit)
    if not UnitExists(unit) then return false end
    
    -- Get unit GUID for tracking
    local guid = UnitGUID(unit)
    if not guid then return false end
    
    -- Skip if we've already processed this unit
    if markedUnits[guid] then return false end
    
    if ShouldMarkUnit(unit) then
        local mark = GetNextAvailableMark()
        if mark then
            SetRaidTarget(unit, mark)
            markedUnits[guid] = true
            DebugPrint("Marked " .. (UnitName(unit) or "Unknown") .. " with mark " .. mark)
            return true
        else
            DebugPrint("No available marks")
        end
    end
    
    return false
end

-- Check if auto-marking is enabled for current group type
local function IsEnabledForCurrentGroup()
    if IsInRaid() then
        return AutoMarkerDB.enabledRaid
    elseif IsInGroup() then
        return AutoMarkerDB.enabledGroup
    else
        return AutoMarkerDB.enabledSolo
    end
end

-- Scan nameplate units for marking
local function ScanForTargets()
    if not AutoMarkerDB.enabled then return end
    if not IsEnabledForCurrentGroup() then return end
    if not UnitAffectingCombat("player") then return end
    if not CanSetRaidTargets() then 
        if AutoMarkerDB.debug then
            DebugPrint("No permission to set raid targets")
        end
        return 
    end
    
    -- Check nameplate units using modern API
    local nameplates = C_NamePlate.GetNamePlates()
    if nameplates then
        for _, nameplate in ipairs(nameplates) do
            if nameplate and nameplate.namePlateUnitToken then
                TryMarkUnit(nameplate.namePlateUnitToken)
            end
        end
    end
    
    -- Also check target and focus
    if UnitExists("target") then
        TryMarkUnit("target")
    end
    
    if UnitExists("focus") then
        TryMarkUnit("focus")
    end
end

-- Event handlers
local function OnPlayerEnterCombat()
    DebugPrint("Entering combat")
    markedUnits = {} -- Reset tracked units
    currentMarkIndex = 1
    
    -- Start scanning ticker (scan every 0.5 seconds)
    if not scanTicker then
        scanTicker = C_Timer.NewTicker(0.5, function()
            ScanForTargets()
        end)
    end
    
    -- Do immediate scan
    ScanForTargets()
end

local function OnPlayerLeaveCombat()
    DebugPrint("Leaving combat")
    markedUnits = {} -- Clear tracked units
    
    -- Stop scanning ticker
    if scanTicker then
        scanTicker:Cancel()
        scanTicker = nil
    end
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        OnPlayerEnterCombat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnPlayerLeaveCombat()
    elseif event == "PLAYER_TARGET_CHANGED" or 
           event == "NAME_PLATE_UNIT_ADDED" then
        if UnitAffectingCombat("player") then
            ScanForTargets()
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = ...
        -- Only scan if it's a nameplate unit and we're in combat
        if unit and string.match(unit, "nameplate") and UnitAffectingCombat("player") then
            ScanForTargets()
        end
    elseif event == "ADDON_LOADED" then
        local addonLoaded = ...
        if addonLoaded == addonName then
            print("|cFF00FF00AutoMarker|r loaded. Use /automarker for commands.")
            -- Create settings panel
            C_Timer.After(1, CreateSettingsPanel)
        end
    end
end

-- Register events
AutoMarker:RegisterEvent("ADDON_LOADED")
AutoMarker:RegisterEvent("PLAYER_REGEN_DISABLED")
AutoMarker:RegisterEvent("PLAYER_REGEN_ENABLED")
AutoMarker:RegisterEvent("PLAYER_TARGET_CHANGED")
AutoMarker:RegisterEvent("NAME_PLATE_UNIT_ADDED")
AutoMarker:RegisterEvent("UNIT_SPELLCAST_START")
AutoMarker:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
AutoMarker:SetScript("OnEvent", OnEvent)

-- Slash commands
SLASH_AUTOMARKER1 = "/automarker"
SLASH_AUTOMARKER2 = "/am"

SlashCmdList["AUTOMARKER"] = function(msg)
    local command = string.lower(msg)
    
    if command == "toggle" or command == "" then
        AutoMarkerDB.enabled = not AutoMarkerDB.enabled
        print("|cFF00FF00AutoMarker|r " .. (AutoMarkerDB.enabled and "enabled" or "disabled"))
    elseif command == "config" or command == "settings" then
        -- Open settings panel
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("AutoMarker")
        else
            InterfaceOptionsFrame_OpenToCategory("AutoMarker")
            InterfaceOptionsFrame_OpenToCategory("AutoMarker") -- Call twice for classic bug
        end
    elseif command == "debug" then
        AutoMarkerDB.debug = not AutoMarkerDB.debug
        print("|cFF00FF00AutoMarker|r debug mode " .. (AutoMarkerDB.debug and "enabled" or "disabled"))
    elseif command == "solo" then
        AutoMarkerDB.enabledSolo = not AutoMarkerDB.enabledSolo
        print("|cFF00FF00AutoMarker|r solo mode: " .. (AutoMarkerDB.enabledSolo and "enabled" or "disabled"))
    elseif command == "group" then
        AutoMarkerDB.enabledGroup = not AutoMarkerDB.enabledGroup
        print("|cFF00FF00AutoMarker|r group mode: " .. (AutoMarkerDB.enabledGroup and "enabled" or "disabled"))
    elseif command == "raid" then
        AutoMarkerDB.enabledRaid = not AutoMarkerDB.enabledRaid
        print("|cFF00FF00AutoMarker|r raid mode: " .. (AutoMarkerDB.enabledRaid and "enabled" or "disabled"))
    elseif command == "help" then
        print("|cFF00FF00AutoMarker Commands:|r")
        print("/automarker or /am - Toggle addon on/off")
        print("/automarker config - Open settings panel")
        print("/automarker solo - Toggle solo mode")
        print("/automarker group - Toggle group mode")
        print("/automarker raid - Toggle raid mode")
        print("/automarker debug - Toggle debug messages")
        print("/automarker help - Show this help")
    else
        print("|cFF00FF00AutoMarker|r Unknown command. Use '/automarker help' for commands.")
    end
end
