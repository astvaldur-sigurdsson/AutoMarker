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

-- Priority order for marking elites
local ELITE_MARK_PRIORITY = {
    MARKS.SKULL,
    MARKS.CROSS
}

-- Priority order for marking non-elites (casters/mana users)
local NORMAL_MARK_PRIORITY = {
    MARKS.DIAMOND,
    MARKS.SQUARE,
    MARKS.MOON,
    MARKS.TRIANGLE,
    MARKS.CIRCLE,
    MARKS.STAR
}

-- Combined priority list for checking used marks
local ALL_MARKS = {
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
    markElites = true,
    markCasters = true,
    markManaUsers = true,
    debug = false,
    debugLog = {} -- Store debug messages
}

-- Debug print function
local function DebugPrint(msg)
    if AutoMarkerDB.debug then
        local timestamp = date("%H:%M:%S")
        local logMsg = timestamp .. " - " .. msg
        print("|cFF00FF00[AutoMarker]|r " .. msg)
        
        -- Initialize debugLog if it doesn't exist
        if not AutoMarkerDB.debugLog then
            AutoMarkerDB.debugLog = {}
        end
        
        -- Also store in log
        table.insert(AutoMarkerDB.debugLog, logMsg)
        
        -- Keep only last 100 messages
        if #AutoMarkerDB.debugLog > 100 then
            table.remove(AutoMarkerDB.debugLog, 1)
        end
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
    groupCheck.Text:SetText("Party (dungeons/delves with NPCs)")
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
    detectHeader:SetText("Mark mobs that are:")
    
    -- Elite checkbox
    local eliteCheck = CreateFrame("CheckButton", "AutoMarkerEliteCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    eliteCheck:SetPoint("TOPLEFT", detectHeader, "BOTTOMLEFT", 16, -8)
    eliteCheck.Text:SetText("Elite mobs (Skull/Cross)")
    eliteCheck:SetChecked(AutoMarkerDB.markElites)
    eliteCheck:SetScript("OnClick", function(self)
        AutoMarkerDB.markElites = self:GetChecked()
    end)
    
    -- Mana checkbox
    local manaCheck = CreateFrame("CheckButton", "AutoMarkerManaCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    manaCheck:SetPoint("TOPLEFT", eliteCheck, "BOTTOMLEFT", 0, -8)
    manaCheck.Text:SetText("Mana users")
    manaCheck:SetChecked(AutoMarkerDB.markManaUsers)
    manaCheck:SetScript("OnClick", function(self)
        AutoMarkerDB.markManaUsers = self:GetChecked()
    end)
    
    -- Casting checkbox
    local castCheck = CreateFrame("CheckButton", "AutoMarkerCastCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    castCheck:SetPoint("TOPLEFT", manaCheck, "BOTTOMLEFT", 0, -8)
    castCheck.Text:SetText("Casters/Channelers")
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
    
    local success, powerType = pcall(UnitPowerType, unit)
    if not success then return false end
    
    -- 0 = Mana
    if powerType == 0 then
        local success2, maxPower = pcall(UnitPowerMax, unit, 0)
        if success2 then
            return maxPower > 0
        end
    end
    return false
end

-- Check if a unit is casting
local function IsCasting(unit)
    if not UnitExists(unit) then return false end
    
    local success, name = pcall(UnitCastingInfo, unit)
    local success2, channelName = pcall(UnitChannelInfo, unit)
    
    return (success and name ~= nil) or (success2 and channelName ~= nil)
end

-- Check if a unit is elite
local function IsElite(unit)
    if not UnitExists(unit) then return false end
    
    local success, classification = pcall(UnitClassification, unit)
    if not success then return false end
    
    -- "elite" = elite, "rareelite" = rare elite, "worldboss" = boss
    return classification == "elite" or classification == "rareelite" or classification == "worldboss"
end

-- Get next available mark (with priority list based on elite status)
local function GetNextAvailableMark(isEliteUnit)
    -- Check which marks are already in use
    local usedMarks = {}
    
    -- Check raid/party members' targets
    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i .. "target"
            if UnitExists(unit) then
                local success, mark = pcall(GetRaidTargetIndex, unit)
                if success and mark then
                    usedMarks[mark] = true
                end
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i .. "target"
            if UnitExists(unit) then
                local success, mark = pcall(GetRaidTargetIndex, unit)
                if success and mark then
                    usedMarks[mark] = true
                end
            end
        end
    end
    
    -- Check player target
    if UnitExists("target") then
        local success, mark = pcall(GetRaidTargetIndex, "target")
        if success and mark then
            usedMarks[mark] = true
        end
    end
    
    -- Choose priority list based on whether unit is elite
    local priorityList = isEliteUnit and ELITE_MARK_PRIORITY or NORMAL_MARK_PRIORITY
    
    -- Return first unused mark from priority list
    for _, markNum in ipairs(priorityList) do
        if not usedMarks[markNum] then
            return markNum
        end
    end
    
    return nil
end

-- Check if unit should be marked
local function ShouldMarkUnit(unit)
    if not UnitExists(unit) then return false, false end
    
    -- Protected unit API calls
    local success, canAttack = pcall(UnitCanAttack, "player", unit)
    if not success or not canAttack then 
        local success2, name = pcall(UnitName, unit)
        name = success2 and name or "Unknown"
        DebugPrint("Unit can't be attacked or is protected: " .. name)
        return false, false 
    end
    
    local success3, isDead = pcall(UnitIsDead, unit)
    if success3 and isDead then 
        local success4, name = pcall(UnitName, unit)
        name = success4 and name or "Unknown"
        DebugPrint("Unit is dead: " .. name)
        return false, false 
    end
    -- Removed strict combat check - mark any enemy in range
    
    -- Check if already marked (protected call)
    local success5, existingMark = pcall(GetRaidTargetIndex, unit)
    if success5 and existingMark then
        DebugPrint("Unit already has a mark")
        return false, false
    end
    
    local isEliteUnit = IsElite(unit)
    
    -- Mark elites if enabled
    if isEliteUnit and AutoMarkerDB.markElites then
        local success, name = pcall(UnitName, unit)
        name = success and name or "Unknown"
        DebugPrint("Found elite unit: " .. name)
        return true, true
    end
    
    -- For non-elites, check if they have mana or are casting
    if AutoMarkerDB.markManaUsers and HasMana(unit) then
        local success, name = pcall(UnitName, unit)
        name = success and name or "Unknown"
        DebugPrint("Found unit with mana: " .. name)
        return true, false
    end
    
    if AutoMarkerDB.markCasters and IsCasting(unit) then
        local success, name = pcall(UnitName, unit)
        name = success and name or "Unknown"
        DebugPrint("Found casting unit: " .. name)
        return true, false
    end
    
    return false, false
end

-- Try to mark a unit
local function TryMarkUnit(unit)
    -- Wrap entire function in pcall to catch any tainted data issues
    local success_full, result = pcall(function()
        if not UnitExists(unit) then 
            DebugPrint("TryMark: Unit doesn't exist")
            return false 
        end
        
        local success, unitName = pcall(UnitName, unit)
        unitName = success and unitName or "Unknown"
        DebugPrint("TryMark: Unit exists - " .. unitName)
        
        -- Get unit GUID for tracking (protected call)
        local success2, guid = pcall(UnitGUID, unit)
        if not success2 or not guid then 
            DebugPrint("TryMark: No GUID (protected unit)")
            return false 
        end
        
        -- Skip if we've already processed this unit (protected access)
        local already_processed = false
        local success3 = pcall(function()
            if markedUnits[guid] then
                already_processed = true
            end
        end)
        
        if already_processed then 
            DebugPrint("TryMark: Already processed")
            return false 
        end
        
        DebugPrint("TryMark: Calling ShouldMarkUnit...")
        local shouldMark, isEliteUnit = ShouldMarkUnit(unit)
        DebugPrint("TryMark: ShouldMarkUnit returned: " .. tostring(shouldMark) .. ", isElite: " .. tostring(isEliteUnit))
        
        if shouldMark then
            local mark = GetNextAvailableMark(isEliteUnit)
            if mark then
                DebugPrint("Attempting to set mark " .. mark .. " on unit")
                
                local success4, err = pcall(SetRaidTarget, unit, mark)
                if not success4 then
                    DebugPrint("Failed to set raid target: " .. tostring(err))
                    return false
                end
                
                -- Immediately verify the mark was set
                local success_verify, currentMark = pcall(GetRaidTargetIndex, unit)
                if success_verify and currentMark == mark then
                    DebugPrint("SUCCESS: Mark " .. mark .. " verified immediately")
                else
                    DebugPrint("FAILED: Mark did not apply. CurrentMark=" .. tostring(currentMark))
                    DebugPrint("This may be due to instance restrictions or another addon")
                    return false
                end
                
                -- Verify again after a short delay
                C_Timer.After(0.5, function()
                    local success_verify2, currentMark2 = pcall(GetRaidTargetIndex, unit)
                    if success_verify2 and currentMark2 == mark then
                        DebugPrint("Mark " .. mark .. " still present after 0.5s")
                    else
                        DebugPrint("WARNING: Mark was cleared after 0.5s! CurrentMark=" .. tostring(currentMark2))
                    end
                end)
                
                -- Mark as processed (protected write)
                pcall(function()
                    markedUnits[guid] = true
                end)
                
                local eliteStr = isEliteUnit and " (elite)" or ""
                local success5, name = pcall(UnitName, unit)
                name = success5 and name or "Unknown"
                DebugPrint("Marked " .. name .. eliteStr .. " with mark " .. mark)
                return true
            else
                DebugPrint("No available marks")
            end
        else
            DebugPrint("TryMark: Should not mark this unit")
        end
        
        return false
    end)
    
    if not success_full then
        DebugPrint("ERROR in TryMarkUnit: " .. tostring(result))
        return false
    end
    
    return result
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
    if not AutoMarkerDB.enabled then 
        DebugPrint("Addon disabled")
        return 
    end
    if not IsEnabledForCurrentGroup() then 
        DebugPrint("Not enabled for current group type")
        return 
    end
    if not UnitAffectingCombat("player") then 
        DebugPrint("Player not in combat")
        return 
    end
    if not CanSetRaidTargets() then 
        DebugPrint("No permission to set raid targets")
        return 
    end
    
    DebugPrint("Scanning for targets...")

    -- First, check if we have a target
    if UnitExists("target") then
        local tName = "Unknown"
        local tIsElite = false
        local tHasMana = false
        local tIsCasting = false
        
        local success, name = pcall(UnitName, "target")
        if success and name then
            tName = name
        end
        
        local success2, elite = pcall(IsElite, "target")
        if success2 then
            tIsElite = elite
        end
        
        local success3, mana = pcall(HasMana, "target")
        if success3 then
            tHasMana = mana
        end
        
        local success4, casting = pcall(IsCasting, "target")
        if success4 then
            tIsCasting = casting
        end
        
        DebugPrint("Target exists: " .. tostring(tName) .. " | Elite:" .. tostring(tIsElite) .. " | Mana:" .. tostring(tHasMana) .. " | Casting:" .. tostring(tIsCasting))
        local success_mark, err_mark = pcall(TryMarkUnit, "target")
        if not success_mark then
            DebugPrint("ERROR marking target: " .. tostring(err_mark))
        end
    else
        DebugPrint("No target selected")
    end
    
    -- Check nameplate units using modern API (with error protection for Plater compatibility)
    DebugPrint("Checking C_NamePlate API...")
    local success, nameplates = pcall(function() return C_NamePlate.GetNamePlates() end)
    
    if not success then
        DebugPrint("ERROR calling C_NamePlate.GetNamePlates(): " .. tostring(nameplates))
        DebugPrint("This may be caused by nameplate addons like Plater")
    elseif nameplates then
        local count = #nameplates
        DebugPrint("Found " .. count .. " nameplates")
        
        if count == 0 then
            DebugPrint("Nameplate array is empty - are enemy nameplates enabled?")
        end
        
        for i, nameplate in ipairs(nameplates) do
            local success2, err = pcall(function()
                if nameplate and nameplate.namePlateUnitToken then
                    DebugPrint("Nameplate " .. i .. ": Token=" .. nameplate.namePlateUnitToken)
                    TryMarkUnit(nameplate.namePlateUnitToken)
                end
            end)
            if not success2 then
                DebugPrint("ERROR processing nameplate " .. i .. ": " .. tostring(err))
            end
        end
    else
        DebugPrint("C_NamePlate.GetNamePlates() returned nil")
    end
    
    -- Alternative: Try nameplate units directly
    DebugPrint("Trying direct nameplate units...")
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            DebugPrint("Found nameplate unit: " .. unit)
            local success_mark, err_mark = pcall(TryMarkUnit, unit)
            if not success_mark then
                DebugPrint("ERROR marking nameplate: " .. tostring(err_mark))
            end
        end
    end
    
    -- Check focus
    if UnitExists("focus") then
        DebugPrint("Checking focus")
        local success_mark, err_mark = pcall(TryMarkUnit, "focus")
        if not success_mark then
            DebugPrint("ERROR marking focus: " .. tostring(err_mark))
        end
    end
end

-- Event handlers
local function OnPlayerEnterCombat()
    DebugPrint("Entering combat")
    markedUnits = {} -- Reset tracked units
    currentMarkIndex = 1
    
    -- Start scanning ticker (scan every 2 seconds to reduce spam)
    if not scanTicker then
        scanTicker = C_Timer.NewTicker(2, function()
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
    
    if command == "" then
        -- Open settings panel
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("AutoMarker")
        else
            InterfaceOptionsFrame_OpenToCategory("AutoMarker")
            InterfaceOptionsFrame_OpenToCategory("AutoMarker") -- Call twice for classic bug
        end
    elseif command == "toggle" then
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
        print("/automarker or /am - Open settings GUI")
        print("/automarker toggle - Toggle addon on/off")
        print("/automarker config - Open settings panel")
        print("/automarker solo - Toggle solo mode")
        print("/automarker group - Toggle group mode")
        print("/automarker raid - Toggle raid mode")
        print("/automarker debug - Toggle debug messages")
        print("/automarker status - Show current settings")
        print("/automarker log - Show debug log")
        print("/automarker clearlog - Clear debug log")
        print("/automarker help - Show this help")
    elseif command == "status" then
        print("|cFF00FF00AutoMarker Status:|r")
        print("Enabled: " .. (AutoMarkerDB.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("Debug: " .. (AutoMarkerDB.debug and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("Solo: " .. (AutoMarkerDB.enabledSolo and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("Group: " .. (AutoMarkerDB.enabledGroup and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("Raid: " .. (AutoMarkerDB.enabledRaid and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("Mark Elites: " .. (AutoMarkerDB.markElites and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("Mark Mana: " .. (AutoMarkerDB.markManaUsers and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("Mark Casters: " .. (AutoMarkerDB.markCasters and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("In Combat: " .. (UnitAffectingCombat("player") and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("Group Type: " .. (IsInRaid() and "Raid" or (IsInGroup() and "Group" or "Solo")))
        print("Can Mark: " .. (CanSetRaidTargets() and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    elseif command == "log" then
        if #AutoMarkerDB.debugLog == 0 then
            print("|cFF00FF00AutoMarker|r Debug log is empty")
        else
            print("|cFF00FF00AutoMarker Debug Log:|r (last " .. #AutoMarkerDB.debugLog .. " messages)")
            for _, msg in ipairs(AutoMarkerDB.debugLog) do
                print(msg)
            end
        end
    elseif command == "clearlog" then
        AutoMarkerDB.debugLog = {}
        print("|cFF00FF00AutoMarker|r Debug log cleared")
    elseif command == "test" or command == "testmark" then
        if not UnitExists("target") then
            print("|cFF00FF00AutoMarker|r No target selected")
        else
            local name = UnitName("target") or "Unknown"
            print("|cFF00FF00AutoMarker|r Testing mark on: " .. name)
            
            -- Try to set skull mark
            local success, err = pcall(SetRaidTarget, "target", 8)
            if not success then
                print("ERROR calling SetRaidTarget: " .. tostring(err))
            else
                print("SetRaidTarget called successfully")
            end
            
            -- Check if it worked
            C_Timer.After(0.1, function()
                local success2, mark = pcall(GetRaidTargetIndex, "target")
                if success2 and mark then
                    print("SUCCESS! Target has mark: " .. mark)
                else
                    print("FAILED! Target has no mark. Mark=" .. tostring(mark))
                end
            end)
        end
    else
        print("|cFF00FF00AutoMarker|r Unknown command. Use '/automarker help' for commands.")
    end
end
