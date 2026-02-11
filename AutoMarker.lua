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
    onlyInGroup = true,
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

-- Scan nameplate units for marking
local function ScanForTargets()
    if not AutoMarkerDB.enabled then return end
    if AutoMarkerDB.onlyInGroup and not IsInGroupOrRaid() then return end
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
    elseif command == "debug" then
        AutoMarkerDB.debug = not AutoMarkerDB.debug
        print("|cFF00FF00AutoMarker|r debug mode " .. (AutoMarkerDB.debug and "enabled" or "disabled"))
    elseif command == "group" then
        AutoMarkerDB.onlyInGroup = not AutoMarkerDB.onlyInGroup
        print("|cFF00FF00AutoMarker|r only in group: " .. (AutoMarkerDB.onlyInGroup and "yes" or "no"))
    elseif command == "help" then
        print("|cFF00FF00AutoMarker Commands:|r")
        print("/automarker or /am - Toggle addon on/off")
        print("/automarker debug - Toggle debug messages")
        print("/automarker group - Toggle 'only in group' requirement")
        print("/automarker help - Show this help")
    else
        print("|cFF00FF00AutoMarker|r Unknown command. Use '/automarker help' for commands.")
    end
end
