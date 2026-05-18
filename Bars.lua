local addonName, ns = ...
local BBHB = ns.BBHB

local STATUSBAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

BBHB.bars = {}
BBHB.anchor = nil
BBHB.testMode = false

local function ApplyFont(fs, size, color)
    fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    if color then fs:SetTextColor(color.r, color.g, color.b, color.a or 1) end
end

local function CreateAnchor()
    local a = CreateFrame("Frame", "BBHB_Anchor", UIParent, "BackdropTemplate")
    a:SetSize(260, 20)
    a:SetMovable(true)
    a:EnableMouse(false)
    a:RegisterForDrag("LeftButton")
    a:SetClampedToScreen(true)
    a:SetFrameStrata("HIGH")
    a:SetScript("OnDragStart", function(self) self:StartMoving() end)
    a:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p = BBHB:GetProfile().bar.position
        local point, _, relPoint, x, y = self:GetPoint(1)
        p.point, p.relPoint, p.x, p.y = point, relPoint, x, y
    end)

    a.bg = a:CreateTexture(nil, "BACKGROUND")
    a.bg:SetAllPoints()
    a.bg:SetColorTexture(0.2, 0.4, 0.9, 0.45)

    a.label = a:CreateFontString(nil, "OVERLAY")
    a.label:SetPoint("CENTER")
    a.label:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    a.label:SetText("BBHB Anchor - drag to move")

    local lockCb = CreateFrame("CheckButton", "BBHB_LockCheckbox", a, "InterfaceOptionsCheckButtonTemplate")
    lockCb:SetPoint("BOTTOMLEFT", a, "TOPLEFT", -4, 2)
    if lockCb.Text then lockCb.Text:SetText("Lock bars") end
    lockCb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        BBHB:GetProfile().bar.locked = checked
        BBHB.testMode = not checked
        BBHB:ApplySettings()
        if BBHB.RefreshOptionsUI then BBHB:RefreshOptionsUI() end
    end)
    lockCb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Lock bars")
        GameTooltip:AddLine("Check to lock the boss bars in place and hide this anchor.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    lockCb:SetScript("OnLeave", GameTooltip_Hide)
    a.lockCb = lockCb

    a:Hide()
    return a
end

local function CreateBar(index)
    local bar = CreateFrame("StatusBar", "BBHB_Bar"..index, UIParent, "BackdropTemplate")
    bar:SetStatusBarTexture(STATUSBAR_TEX)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetFrameStrata("MEDIUM")

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.55)

    bar.border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.border:SetPoint("TOPLEFT", -1, 1)
    bar.border:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar.border:SetBackdropBorderColor(0, 0, 0, 1)

    bar.nameText    = bar:CreateFontString(nil, "OVERLAY")
    bar.percentText = bar:CreateFontString(nil, "OVERLAY")

    -- Cast bar (child)
    local cast = CreateFrame("StatusBar", nil, bar)
    cast:SetStatusBarTexture(STATUSBAR_TEX)
    cast:SetMinMaxValues(0, 1)
    cast:SetValue(0)
    cast.bg = cast:CreateTexture(nil, "BACKGROUND")
    cast.bg:SetAllPoints()
    cast.bg:SetColorTexture(0, 0, 0, 0.6)
    cast.text = cast:CreateFontString(nil, "OVERLAY")
    cast.text:SetPoint("LEFT", 4, 0)
    cast.text:SetJustifyH("LEFT")
    cast.timeText = cast:CreateFontString(nil, "OVERLAY")
    cast.timeText:SetPoint("RIGHT", -4, 0)
    cast.timeText:SetJustifyH("RIGHT")
    cast.icon = cast:CreateTexture(nil, "ARTWORK")
    cast.icon:SetPoint("RIGHT", cast, "LEFT", -2, 0)
    cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cast:Hide()

    bar.cast = cast
    bar:Hide()
    return bar
end

local function CreateMajorRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.time = row:CreateFontString(nil, "OVERLAY")
    row.time:SetJustifyH("RIGHT")
    row.time:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    row:Hide()
    return row
end

local function CreateMajorPanel()
    local p = CreateFrame("Frame", "BBHB_MajorPanel", UIParent)
    p:SetSize(200, 80)
    p:SetFrameStrata("MEDIUM")
    p.rows = {}
    for i = 1, 20 do
        p.rows[i] = CreateMajorRow(p, i)
    end
    p:Hide()
    return p
end

function BBHB:BuildBars()
    if self.anchor then return end
    self.anchor = CreateAnchor()
    for i = 1, BBHB.MAX_BOSSES do
        self.bars[i] = CreateBar(i)
        self.bars[i].index = i
    end
    self.majorPanel = CreateMajorPanel()
    self.majorTimers = {}
    self._nextTimerID = 0
    self.majorPanel:SetScript("OnUpdate", function() BBHB:UpdateMajorPanel() end)
end

local function unpackColor(c) return c.r, c.g, c.b, c.a or 1 end

function BBHB:LayoutBars()
    local cfg  = BBHB:GetProfile().bar
    local ccfg = BBHB:GetProfile().cast
    local pos  = cfg.position

    self.anchor:ClearAllPoints()
    self.anchor:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
    self.anchor:SetSize(cfg.width, 18)
    if self.anchor.lockCb then self.anchor.lockCb:SetChecked(cfg.locked) end

    if cfg.locked then
        self.anchor:Hide()
        self.anchor:EnableMouse(false)
    else
        self.anchor:Show()
        self.anchor:EnableMouse(true)
    end

    -- Compute gap so name (ABOVE/BELOW) and cast bar don't overlap neighbors.
    local extra = 0
    if ccfg.enabled then extra = extra + ccfg.height + 1 end
    if cfg.showBossName and (cfg.bossNamePosition == "ABOVE" or cfg.bossNamePosition == "BELOW") then
        extra = extra + cfg.fontSize + 4
    end
    local gap = cfg.spacing + extra

    local growUp = cfg.growDirection == "UP"
    local prev = nil
    for i = 1, BBHB.MAX_BOSSES do
        local bar = self.bars[i]
        bar:SetSize(cfg.width, cfg.height)
        bar:ClearAllPoints()
        if not prev then
            if growUp then
                bar:SetPoint("BOTTOM", self.anchor, "TOP", 0, gap)
            else
                bar:SetPoint("TOP", self.anchor, "BOTTOM", 0, -gap)
            end
        else
            if growUp then
                bar:SetPoint("BOTTOM", prev, "TOP", 0, gap)
            else
                bar:SetPoint("TOP", prev, "BOTTOM", 0, -gap)
            end
        end
        prev = bar
    end
end

function BBHB:StyleBar(bar)
    local cfg  = BBHB:GetProfile().bar
    local ccfg = BBHB:GetProfile().cast

    bar:SetStatusBarColor(unpackColor(cfg.color))
    bar.bg:SetColorTexture(unpackColor(cfg.bgColor))
    bar.border:SetBackdropBorderColor(unpackColor(cfg.borderColor))

    -- Name placement
    bar.nameText:ClearAllPoints()
    ApplyFont(bar.nameText, cfg.fontSize, cfg.textColor)
    bar.nameText:SetWordWrap(false)
    bar.nameText:SetJustifyV("MIDDLE")
    bar.nameText:SetHeight(cfg.fontSize + 4)
    local align = cfg.bossNameAlign or "LEFT"
    if cfg.bossNamePosition == "ABOVE" then
        bar.nameText:SetWidth(cfg.width - 4)
        if align == "LEFT" then
            bar.nameText:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 2, 2)
        elseif align == "RIGHT" then
            bar.nameText:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -2, 2)
        else
            bar.nameText:SetPoint("BOTTOM", bar, "TOP", 0, 2)
        end
    elseif cfg.bossNamePosition == "BELOW" then
        local drop = 2
        if ccfg.enabled then drop = drop + ccfg.height + 1 end
        bar.nameText:SetWidth(cfg.width - 4)
        if align == "LEFT" then
            bar.nameText:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 2, -drop)
        elseif align == "RIGHT" then
            bar.nameText:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -2, -drop)
        else
            bar.nameText:SetPoint("TOP", bar, "BOTTOM", 0, -drop)
        end
    else
        local rightInset = cfg.showPercent and 50 or 4
        if align == "LEFT" then
            bar.nameText:SetWidth(cfg.width - 4 - rightInset)
            bar.nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
        elseif align == "RIGHT" then
            bar.nameText:SetWidth(cfg.width - 4 - rightInset)
            bar.nameText:SetPoint("RIGHT", bar, "RIGHT", -rightInset, 0)
        else
            bar.nameText:SetWidth(cfg.width - 8)
            bar.nameText:SetPoint("CENTER", bar, "CENTER", 0, 0)
        end
    end
    bar.nameText:SetJustifyH(align)
    bar.nameText:SetShown(cfg.showBossName)

    -- Percent
    bar.percentText:ClearAllPoints()
    bar.percentText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    ApplyFont(bar.percentText, cfg.fontSize, cfg.textColor)
    bar.percentText:SetShown(cfg.showPercent)

    -- Cast bar
    local cast = bar.cast
    cast:ClearAllPoints()
    cast:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -1)
    cast:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -1)
    cast:SetHeight(ccfg.height)
    cast.bg:SetColorTexture(unpackColor(ccfg.bgColor))
    ApplyFont(cast.text, ccfg.fontSize, ccfg.textColor)
    ApplyFont(cast.timeText, ccfg.fontSize, ccfg.textColor)

    cast.icon:ClearAllPoints()
    if ccfg.bigIcon then
        local bigH = cfg.height + ccfg.height + 1
        cast.icon:SetSize(bigH, bigH)
        cast.icon:SetPoint("TOPRIGHT", bar, "TOPLEFT", -3, 0)
    else
        cast.icon:SetSize(ccfg.height, ccfg.height)
        cast.icon:SetPoint("RIGHT", cast, "LEFT", -2, 0)
    end
end

function BBHB:ApplySettings()
    if not self.anchor then return end
    self:LayoutBars()
    for i = 1, BBHB.MAX_BOSSES do
        self:StyleBar(self.bars[i])
    end
    local cfg = BBHB:GetProfile().bar
    if self.testMode or not cfg.locked then
        self:ApplyTestValues()
        self:SetTestMajorTimers(true)
    else
        self:SetTestMajorTimers(false)
        self:RefreshAllBosses()
    end
    self:LayoutMajorPanel()
end

local function FormatTime(s)
    if s <= 0 then return "0.0" end
    if s < 10 then return string.format("%.1f", s) end
    return string.format("%d", s)
end

function BBHB:UpdateBossBar(unit)
    local index = tonumber(unit:match("boss(%d+)"))
    if not index or index > BBHB.MAX_BOSSES then return end
    local bar = self.bars[index]
    if not bar then return end
    local cfg = BBHB:GetProfile().bar

    if UnitExists(unit) and not UnitIsDead(unit) then
        local max = UnitHealthMax(unit)
        local cur = UnitHealth(unit)
        if max and max > 0 then
            bar:SetMinMaxValues(0, max)
            bar:SetValue(cur)
            local pct = (cur / max) * 100
            bar.percentText:SetText(string.format("%.1f%%", pct))
        else
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            bar.percentText:SetText("")
        end
        bar.nameText:SetText(UnitName(unit) or "")
        bar:Show()
        -- Check running cast
        if BBHB:GetProfile().cast.enabled then
            BBHB:RefreshCast(unit)
        else
            bar.cast:Hide()
        end
    else
        bar:Hide()
        bar.cast:Hide()
    end
end

function BBHB:RefreshAllBosses()
    if not self.bars or not self.bars[1] then return end
    for i = 1, BBHB.MAX_BOSSES do
        BBHB:UpdateBossBar("boss"..i)
    end
end

-- ===== Cast bar logic =====

local function getCastInfo(unit)
    local name, text, texture, startMS, endMS, isTradeSkill, castID, notInterruptible, spellId = UnitCastingInfo(unit)
    if name then return name, text, texture, startMS, endMS, notInterruptible, false end
    local cName, cText, cTex, cStart, cEnd, _, cNotInt, cSpell = UnitChannelInfo(unit)
    if cName then return cName, cText, cTex, cStart, cEnd, cNotInt, true end
    return nil
end

local function setCastColor(cast, notInterruptible)
    local ccfg = BBHB:GetProfile().cast
    local c = notInterruptible and ccfg.notKickableColor or ccfg.kickableColor
    cast:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
end

function BBHB:StartCast(unit, isChannel)
    local cfg = BBHB:GetProfile().cast
    if not cfg.enabled then return end
    local index = tonumber(unit:match("boss(%d+)"))
    if not index then return end
    local bar = self.bars[index]
    if not bar then return end
    BBHB:RefreshCast(unit)
end

function BBHB:RefreshCast(unit)
    local index = tonumber(unit:match("boss(%d+)"))
    if not index then return end
    local bar = self.bars[index]
    if not bar then return end
    local cast = bar.cast
    local cfg = BBHB:GetProfile().cast

    local name, text, texture, startMS, endMS, notInterruptible, isChannel = getCastInfo(unit)
    if not name then
        cast:Hide()
        return
    end

    cast._startMS = startMS
    cast._endMS = endMS
    cast._isChannel = isChannel

    cast:SetMinMaxValues(startMS / 1000, endMS / 1000)
    setCastColor(cast, notInterruptible)
    cast.icon:SetTexture(texture)
    cast.icon:SetShown(texture ~= nil)
    if cfg.showSpellName then
        cast.text:SetText(name)
        cast.text:Show()
    else
        cast.text:Hide()
    end
    cast:Show()

    cast:SetScript("OnUpdate", function(self)
        local liveCfg = BBHB:GetProfile().cast
        local now = GetTime()
        local s = self._startMS / 1000
        local e = self._endMS / 1000
        if now >= e then
            self:Hide()
            self:SetScript("OnUpdate", nil)
            return
        end
        if self._isChannel then
            self:SetValue(e - now + s)
        else
            self:SetValue(now)
        end
        if liveCfg.showCastTime then
            self.timeText:SetText(FormatTime(e - now))
            self.timeText:Show()
        else
            self.timeText:Hide()
        end
    end)
end

function BBHB:StopCast(unit)
    local index = tonumber(unit:match("boss(%d+)"))
    if not index then return end
    local bar = self.bars[index]
    if not bar then return end
    bar.cast:Hide()
    bar.cast:SetScript("OnUpdate", nil)
end

function BBHB:UpdateCastTiming(unit)
    local index = tonumber(unit:match("boss(%d+)"))
    if not index then return end
    local bar = self.bars[index]
    if not bar then return end
    local _, _, _, startMS, endMS = getCastInfo(unit)
    if not startMS then return end
    bar.cast._startMS = startMS
    bar.cast._endMS = endMS
    bar.cast:SetMinMaxValues(startMS / 1000, endMS / 1000)
end

function BBHB:UpdateCastKickable(unit)
    local index = tonumber(unit:match("boss(%d+)"))
    if not index then return end
    local bar = self.bars[index]
    if not bar then return end
    local _, _, _, _, _, notInt = getCastInfo(unit)
    setCastColor(bar.cast, notInt)
end

-- ===== Major spell timers =====

function BBHB:AddMajorTimer(spellName, duration, icon, preview)
    if not self.majorTimers then return end
    self._nextTimerID = (self._nextTimerID or 0) + 1
    local now = GetTime()
    local t = {
        id = self._nextTimerID,
        spellName = spellName or "Unknown",
        icon = icon or 134400,
        startTime = now,
        duration = duration,
        expireTime = now + duration,
        isPreview = preview and true or false,
    }
    table.insert(self.majorTimers, t)
    BBHB:LayoutMajorPanel()
    return t.id
end

function BBHB:RemoveMajorTimer(id)
    if not self.majorTimers then return end
    for i, t in ipairs(self.majorTimers) do
        if t.id == id then
            table.remove(self.majorTimers, i)
            BBHB:LayoutMajorPanel()
            return
        end
    end
end

function BBHB:ClearMajorTimers()
    if not self.majorTimers then return end
    wipe(self.majorTimers)
    BBHB:LayoutMajorPanel()
end

function BBHB:ClearPreviewMajorTimers()
    if not self.majorTimers then return end
    local i = 1
    while i <= #self.majorTimers do
        if self.majorTimers[i].isPreview then
            table.remove(self.majorTimers, i)
        else
            i = i + 1
        end
    end
end

function BBHB:LayoutMajorPanel()
    if not self.majorPanel then return end
    local mcfg = BBHB:GetProfile().majorSpells
    local panel = self.majorPanel

    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", self.anchor, "TOPRIGHT", mcfg.offsetX or 8, mcfg.offsetY or 0)

    local rowH = mcfg.iconSize
    local rowSpacing = 2
    local width = math.max(140, rowH * 5)
    panel:SetSize(width, (rowH + rowSpacing) * mcfg.maxShown)

    for i = 1, #panel.rows do
        local row = panel.rows[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(i - 1) * (rowH + rowSpacing))
        row:SetSize(width, rowH)
        row.bg:SetColorTexture(mcfg.bgColor.r, mcfg.bgColor.g, mcfg.bgColor.b, mcfg.bgColor.a or 0.55)
        row.icon:SetSize(rowH, rowH)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -42, 0)
        row.name:SetHeight(mcfg.fontSize + 4)
        row.name:SetFont(STANDARD_TEXT_FONT, mcfg.fontSize, "OUTLINE")
        row.name:SetTextColor(mcfg.color.r, mcfg.color.g, mcfg.color.b, mcfg.color.a or 1)
        row.name:SetShown(mcfg.showName)
        row.time:SetFont(STANDARD_TEXT_FONT, mcfg.fontSize, "OUTLINE")
        row.time:SetTextColor(mcfg.color.r, mcfg.color.g, mcfg.color.b, mcfg.color.a or 1)
        row.time:SetShown(mcfg.showTime)
    end

    panel:SetShown(mcfg.enabled and #self.majorTimers > 0)
    BBHB:UpdateMajorPanel()
end

function BBHB:UpdateMajorPanel()
    if not self.majorPanel or not self.majorTimers then return end
    local mcfg = BBHB:GetProfile().majorSpells
    if not mcfg.enabled then
        self.majorPanel:Hide()
        return
    end
    local now = GetTime()

    -- Expire / loop
    local i = 1
    while i <= #self.majorTimers do
        local t = self.majorTimers[i]
        if t.isPreview then
            if now >= t.expireTime then
                t.startTime = now
                t.expireTime = now + t.duration
            end
            i = i + 1
        elseif now >= t.expireTime then
            table.remove(self.majorTimers, i)
        else
            i = i + 1
        end
    end

    table.sort(self.majorTimers, function(a, b) return a.expireTime < b.expireTime end)

    local panel = self.majorPanel
    local count = math.min(mcfg.maxShown, #self.majorTimers)
    panel:SetShown(count > 0)

    for idx = 1, #panel.rows do
        local row = panel.rows[idx]
        local t = self.majorTimers[idx]
        if idx <= count and t then
            row.icon:SetTexture(t.icon)
            if mcfg.showName then row.name:SetText(t.spellName) end
            local remain = t.expireTime - now
            if remain < 0 then remain = 0 end
            if mcfg.showTime then
                row.time:SetText(string.format(remain < 10 and "%.1f" or "%d", remain))
            end
            if remain <= (mcfg.warningThreshold or 5) then
                local wc = mcfg.warningColor
                row.name:SetTextColor(wc.r, wc.g, wc.b, wc.a or 1)
                row.time:SetTextColor(wc.r, wc.g, wc.b, wc.a or 1)
            else
                local c = mcfg.color
                row.name:SetTextColor(c.r, c.g, c.b, c.a or 1)
                row.time:SetTextColor(c.r, c.g, c.b, c.a or 1)
            end
            row:Show()
        else
            row:Hide()
        end
    end
end

-- ===== Test mode =====

local TEST_SPELLS = {
    { name = "Shadow Bolt",    icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt",   duration = 3.5, kickable = true  },
    { name = "Fel Inferno",    icon = "Interface\\Icons\\Spell_Fire_FelImmolation",  duration = 5.0, kickable = false },
    { name = "Crushing Blow",  icon = "Interface\\Icons\\Ability_Warrior_Savageblow", duration = 2.5, kickable = true  },
}

function BBHB:ApplyTestValues()
    local count = math.min(3, BBHB.MAX_BOSSES)
    local now = GetTime()
    for i = 1, count do
        local bar = self.bars[i]
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(100 - i * 20)
        bar.nameText:SetText("Boss Test " .. i)
        bar.percentText:SetText(string.format("%.1f%%", 100 - i * 20))
        bar:Show()

        local cast = bar.cast
        local spell = TEST_SPELLS[i] or TEST_SPELLS[1]
        local ccfg = BBHB:GetProfile().cast
        cast:SetScript("OnUpdate", nil)
        cast._previewStart = now - (i - 1) * 0.8
        cast._previewDuration = spell.duration
        cast:SetMinMaxValues(0, spell.duration)
        cast:SetValue(0)
        setCastColor(cast, not spell.kickable)
        cast.icon:SetTexture(spell.icon)
        cast.icon:Show()
        if ccfg.showSpellName then
            cast.text:SetText(spell.name)
            cast.text:Show()
        else
            cast.text:Hide()
        end
        cast:Show()
        cast:SetScript("OnUpdate", function(self)
            local liveCfg = BBHB:GetProfile().cast
            local elapsed = (GetTime() - self._previewStart) % self._previewDuration
            self:SetValue(elapsed)
            if liveCfg.showCastTime then
                self.timeText:SetText(FormatTime(self._previewDuration - elapsed))
                self.timeText:Show()
            else
                self.timeText:Hide()
            end
        end)
    end
    for i = count + 1, BBHB.MAX_BOSSES do
        self.bars[i]:Hide()
        self.bars[i].cast:SetScript("OnUpdate", nil)
        self.bars[i].cast:Hide()
    end
end

local TEST_TIMERS = {
    { "Twilight Roar",  18, "Interface\\Icons\\Spell_Shadow_PsychicScream" },
    { "Meteor Crash",   25, "Interface\\Icons\\Spell_Fire_SelfDestruct" },
    { "Mind Sear",       8, "Interface\\Icons\\Spell_Shadow_MindSear" },
    { "Devastation",    45, "Interface\\Icons\\Spell_Fire_Fireball02" },
    { "Wing Buffet",    12, "Interface\\Icons\\INV_Misc_MonsterClaw_03" },
}

function BBHB:SetTestMajorTimers(enable)
    BBHB:ClearPreviewMajorTimers()
    if enable then
        local maxShown = BBHB:GetProfile().majorSpells.maxShown or 5
        for i = 1, math.min(#TEST_TIMERS, maxShown) do
            local e = TEST_TIMERS[i]
            BBHB:AddMajorTimer(e[1], e[2], e[3], true)
        end
    end
end

function BBHB:ToggleTestMode()
    self.testMode = not self.testMode
    local cfg = BBHB:GetProfile().bar
    cfg.locked = not self.testMode
    if self.testMode then
        BBHB:Print("Test mode ON (bars unlocked).")
    else
        BBHB:Print("Test mode OFF.")
    end
    if BBHB.RefreshOptionsUI then BBHB:RefreshOptionsUI() end
    BBHB:ApplySettings()
end
