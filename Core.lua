local addonName, ns = ...

BetterBossHealthBar = {}
local BBHB = BetterBossHealthBar
ns.BBHB = BBHB

BBHB.MAX_BOSSES = 10
BBHB.eventFrame = CreateFrame("Frame", "BBHB_EventFrame", UIParent)

BBHB.defaults = {
    bar = {
        width = 260,
        height = 26,
        spacing = 4,
        color           = { r = 0.80, g = 0.10, b = 0.10, a = 0.95 },
        bgColor         = { r = 0.00, g = 0.00, b = 0.00, a = 0.55 },
        borderColor     = { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },
        textColor       = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
        position        = { point = "CENTER", relPoint = "CENTER", x = 300, y = 50 },
        locked          = true,
        showPercent     = true,
        showBossName    = true,
        bossNamePosition= "INSIDE",  -- INSIDE | ABOVE | BELOW
        bossNameAlign   = "LEFT",    -- LEFT | CENTER | RIGHT
        fontSize        = 12,
        growDirection   = "DOWN",    -- DOWN | UP
    },
    cast = {
        enabled            = true,
        height             = 14,
        kickableColor      = { r = 0.20, g = 0.80, b = 0.25, a = 1.00 },
        notKickableColor   = { r = 0.85, g = 0.10, b = 0.10, a = 1.00 },
        bgColor            = { r = 0.00, g = 0.00, b = 0.00, a = 0.55 },
        textColor          = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
        showSpellName      = true,
        showCastTime       = true,
        fontSize           = 11,
        bigIcon            = false,
    },
    majorSpells = {
        enabled            = true,
        iconSize           = 26,
        fontSize           = 11,
        maxShown           = 5,
        showName           = true,
        showTime           = true,
        offsetX            = 8,
        offsetY            = 0,
        color              = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
        bgColor            = { r = 0.00, g = 0.00, b = 0.00, a = 0.55 },
        warningThreshold   = 5,
        warningColor       = { r = 1.00, g = 0.30, b = 0.30, a = 1.00 },
    },
}

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = deepCopy(v) end
    return r
end
BBHB.deepCopy = deepCopy

local function mergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            mergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end
BBHB.mergeDefaults = mergeDefaults

function BBHB:GetProfile()
    local db = BetterBossHealthBarDB
    return db.profiles[db.currentProfile]
end

function BBHB:GetProfileNames()
    local list = {}
    for name in pairs(BetterBossHealthBarDB.profiles) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function BBHB:CreateProfile(name)
    if not name or name == "" then return false end
    if BetterBossHealthBarDB.profiles[name] then return false end
    BetterBossHealthBarDB.profiles[name] = deepCopy(BBHB.defaults)
    return true
end

function BBHB:CopyProfileFrom(srcName, dstName)
    if not BetterBossHealthBarDB.profiles[srcName] then return false end
    BetterBossHealthBarDB.profiles[dstName] = deepCopy(BetterBossHealthBarDB.profiles[srcName])
    return true
end

function BBHB:DeleteProfile(name)
    if name == "Default" then return false end
    if not BetterBossHealthBarDB.profiles[name] then return false end
    BetterBossHealthBarDB.profiles[name] = nil
    if BetterBossHealthBarDB.currentProfile == name then
        BetterBossHealthBarDB.currentProfile = "Default"
    end
    return true
end

function BBHB:SwitchProfile(name)
    if not BetterBossHealthBarDB.profiles[name] then return false end
    BetterBossHealthBarDB.currentProfile = name
    mergeDefaults(BetterBossHealthBarDB.profiles[name], BBHB.defaults)
    BBHB:ApplySettings()
    return true
end

function BBHB:ResetProfile()
    BetterBossHealthBarDB.profiles[BetterBossHealthBarDB.currentProfile] = deepCopy(BBHB.defaults)
    BBHB:ApplySettings()
end

function BBHB:InitDB()
    if type(BetterBossHealthBarDB) ~= "table" then
        BetterBossHealthBarDB = {}
    end
    if type(BetterBossHealthBarDB.profiles) ~= "table" then
        BetterBossHealthBarDB.profiles = {}
    end
    if not BetterBossHealthBarDB.profiles.Default then
        BetterBossHealthBarDB.profiles.Default = deepCopy(BBHB.defaults)
    end
    if not BetterBossHealthBarDB.currentProfile or not BetterBossHealthBarDB.profiles[BetterBossHealthBarDB.currentProfile] then
        BetterBossHealthBarDB.currentProfile = "Default"
    end
    for _, p in pairs(BetterBossHealthBarDB.profiles) do
        mergeDefaults(p, BBHB.defaults)
    end
end

function BBHB:Print(msg)
    print("|cff4ec1ffBBHB|r: " .. tostring(msg))
end

local f = BBHB.eventFrame
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("UNIT_TARGETABLE_CHANGED")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("UNIT_MAXHEALTH")
f:RegisterEvent("UNIT_NAME_UPDATE")
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_STOP")
f:RegisterEvent("UNIT_SPELLCAST_FAILED")
f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
f:RegisterEvent("UNIT_SPELLCAST_DELAYED")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")

local function isBossUnit(unit)
    if not unit then return false end
    return unit:match("^boss%d+$") ~= nil
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            BBHB:InitDB()
        end
    elseif event == "PLAYER_LOGIN" then
        BBHB:BuildBars()
        BBHB:BuildOptions()
        BBHB:ApplySettings()
        BBHB:RefreshAllBosses()
        BBHB:Print("Loaded. Use /bbhb to open options.")
    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT"
        or event == "ENCOUNTER_START"
        or event == "ENCOUNTER_END" then
        BBHB:RefreshAllBosses()
    elseif event == "UNIT_TARGETABLE_CHANGED" or event == "UNIT_HEALTH"
        or event == "UNIT_MAXHEALTH" or event == "UNIT_NAME_UPDATE" then
        local unit = ...
        if isBossUnit(unit) then
            BBHB:UpdateBossBar(unit)
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = ...
        if isBossUnit(unit) then
            BBHB:StartCast(unit, event == "UNIT_SPELLCAST_CHANNEL_START")
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit = ...
        if isBossUnit(unit) then
            BBHB:StopCast(unit)
        end
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local unit = ...
        if isBossUnit(unit) then
            BBHB:UpdateCastTiming(unit)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        local unit = ...
        if isBossUnit(unit) then
            BBHB:UpdateCastKickable(unit)
        end
    end
end)

SLASH_BBHB1 = "/bbhb"
SLASH_BBHB2 = "/betterbosshealthbar"
SlashCmdList["BBHB"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "lock" then
        BBHB:GetProfile().bar.locked = true
        BBHB.testMode = false
        BBHB:ApplySettings()
        if BBHB.RefreshOptionsUI then BBHB:RefreshOptionsUI() end
        BBHB:Print("Bars locked.")
    elseif msg == "unlock" then
        BBHB:GetProfile().bar.locked = false
        BBHB.testMode = true
        BBHB:ApplySettings()
        if BBHB.RefreshOptionsUI then BBHB:RefreshOptionsUI() end
        BBHB:Print("Bars unlocked - drag to move.")
    elseif msg == "test" then
        BBHB:ToggleTestMode()
    elseif msg == "reset" then
        BBHB:ResetProfile()
        BBHB:Print("Current profile reset to defaults.")
    elseif msg == "cleartimers" then
        BBHB:ClearMajorTimers()
        BBHB:Print("All major timers cleared.")
    elseif msg:match("^timer%s") then
        local dur, name = msg:match("^timer%s+(%d+%.?%d*)%s+(.+)$")
        if dur and name then
            BBHB:AddMajorTimer(name, tonumber(dur))
            BBHB:Print(("Added timer '%s' (%s s)."):format(name, dur))
        else
            BBHB:Print("Usage: /bbhb timer <seconds> <spell name>")
        end
    else
        BBHB:OpenOptions()
    end
end
