local addonName, ns = ...
local BBHB = ns.BBHB

local panel
local widgets = {}

-- ===== Helpers =====

local function CreateLabel(parent, text, size)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetText(text)
    if size then fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
    return fs
end

local function CreateHeader(parent, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetText(text)
    fs:SetTextColor(1, 0.82, 0)
    return fs
end

local function CreateCheckbox(parent, label, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb.Text:SetText(label)
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        BBHB:ApplySettings()
    end)
    cb._refresh = function() cb:SetChecked(getter() and true or false) end
    table.insert(widgets, cb)
    return cb
end

local function CreateSlider(parent, label, minV, maxV, step, getter, setter)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(260, 38)

    local s = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", 0, -8)
    s:SetWidth(220)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s.Low:SetText(tostring(minV))
    s.High:SetText(tostring(maxV))
    s.Text:SetText(label)

    local val = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    val:SetPoint("LEFT", s, "RIGHT", 8, 1)

    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        val:SetText(tostring(v))
        if getter() ~= v then
            setter(v)
            BBHB:ApplySettings()
        end
    end)
    frame._refresh = function()
        local v = getter()
        s:SetValue(v)
        val:SetText(tostring(v))
    end
    table.insert(widgets, frame)
    return frame
end

local function colorToHex(c)
    local r = math.floor((c.r or 0) * 255 + 0.5)
    local g = math.floor((c.g or 0) * 255 + 0.5)
    local b = math.floor((c.b or 0) * 255 + 0.5)
    return string.format("%02X%02X%02X", r, g, b)
end

local function parseHex(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^#", "")
    if #s == 3 then
        s = s:sub(1,1):rep(2) .. s:sub(2,2):rep(2) .. s:sub(3,3):rep(2)
    end
    if #s ~= 6 or s:match("[^0-9A-Fa-f]") then return nil end
    local r = tonumber(s:sub(1, 2), 16) / 255
    local g = tonumber(s:sub(3, 4), 16) / 255
    local b = tonumber(s:sub(5, 6), 16) / 255
    return r, g, b
end

local function CreateColorSwatch(parent, label, getter, setter)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(320, 22)

    local swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
    swatch:SetSize(20, 20)
    swatch:SetPoint("LEFT")
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    swatch:SetBackdropBorderColor(0, 0, 0, 1)

    local hexBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    hexBox:SetSize(70, 20)
    hexBox:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
    hexBox:SetAutoFocus(false)
    hexBox:SetMaxLetters(7)
    hexBox:SetFontObject("GameFontHighlightSmall")

    local txt = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    txt:SetPoint("LEFT", hexBox, "RIGHT", 8, 0)
    txt:SetText(label)

    local function commitHex()
        local r, g, b = parseHex(hexBox:GetText())
        if not r then
            local c = getter()
            hexBox:SetText("#" .. colorToHex(c))
            return
        end
        local cur = getter()
        local a = cur.a or 1
        setter({ r = r, g = g, b = b, a = a })
        swatch:SetBackdropColor(r, g, b, a)
        hexBox:SetText("#" .. colorToHex({ r = r, g = g, b = b }))
        hexBox:ClearFocus()
        BBHB:ApplySettings()
    end
    hexBox:SetScript("OnEnterPressed", commitHex)
    hexBox:SetScript("OnEscapePressed", function(self)
        local c = getter()
        self:SetText("#" .. colorToHex(c))
        self:ClearFocus()
    end)
    hexBox:SetScript("OnEditFocusLost", commitHex)

    swatch:SetScript("OnClick", function()
        local c = getter()
        local function apply()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a
            if ColorPickerFrame.GetColorAlpha then
                a = ColorPickerFrame:GetColorAlpha()
            elseif OpacitySliderFrame then
                a = 1 - OpacitySliderFrame:GetValue()
            else
                a = 1
            end
            setter({ r = r, g = g, b = b, a = a })
            swatch:SetBackdropColor(r, g, b, a)
            hexBox:SetText("#" .. colorToHex({ r = r, g = g, b = b }))
            BBHB:ApplySettings()
        end
        local info = {
            swatchFunc  = apply,
            opacityFunc = apply,
            cancelFunc  = function(prev)
                if not prev then return end
                local pr = prev.r or prev[1] or 1
                local pg = prev.g or prev[2] or 1
                local pb = prev.b or prev[3] or 1
                local pa = prev.a or prev[4] or 1
                setter({ r = pr, g = pg, b = pb, a = pa })
                swatch:SetBackdropColor(pr, pg, pb, pa)
                hexBox:SetText("#" .. colorToHex({ r = pr, g = pg, b = pb }))
                BBHB:ApplySettings()
            end,
            hasOpacity = true,
            opacity = c.a or 1,
            r = c.r, g = c.g, b = c.b,
            previousValues = { r = c.r, g = c.g, b = c.b, a = c.a or 1 },
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func           = info.swatchFunc
            ColorPickerFrame.opacityFunc    = info.opacityFunc
            ColorPickerFrame.cancelFunc     = info.cancelFunc
            ColorPickerFrame.hasOpacity     = info.hasOpacity
            ColorPickerFrame.opacity        = 1 - info.opacity
            ColorPickerFrame.previousValues = info.previousValues
            ColorPickerFrame:SetColorRGB(info.r, info.g, info.b)
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
        end
    end)

    frame._refresh = function()
        local c = getter()
        swatch:SetBackdropColor(c.r, c.g, c.b, c.a or 1)
        if not hexBox:HasFocus() then
            hexBox:SetText("#" .. colorToHex(c))
        end
    end
    table.insert(widgets, frame)
    return frame
end

local function CreateDropdown(parent, label, options, getter, setter)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(260, 44)
    local txt = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    txt:SetPoint("TOPLEFT")
    txt:SetText(label)

    local dd = CreateFrame("Frame", "BBHB_DD_"..math.random(1, 1e9), frame, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", txt, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(dd, 160)

    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, opt in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.value = opt.value
            info.func = function()
                setter(opt.value)
                UIDropDownMenu_SetSelectedValue(dd, opt.value)
                UIDropDownMenu_SetText(dd, opt.text)
                BBHB:ApplySettings()
            end
            info.checked = (getter() == opt.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    frame._refresh = function()
        local cur = getter()
        for _, opt in ipairs(options) do
            if opt.value == cur then
                UIDropDownMenu_SetSelectedValue(dd, cur)
                UIDropDownMenu_SetText(dd, opt.text)
                return
            end
        end
    end
    table.insert(widgets, frame)
    return frame
end

local function CreateButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(120, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

-- ===== Build panel =====

function BBHB:BuildOptions()
    if panel then return end

    panel = CreateFrame("Frame", "BBHB_OptionsPanel", UIParent)
    panel.name = "Better Boss Health Bar"
    panel:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 1200)
    scroll:SetScrollChild(content)

    local title = CreateHeader(content, "Better Boss Health Bar")
    title:SetPoint("TOPLEFT", 10, -10)

    local subtitle = CreateLabel(content, "Type /bbhb test to preview - /bbhb unlock to drag.", 11)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    -- === Layout helper ===
    local y = -60
    local x = 10
    local function place(widget)
        widget:SetParent(content)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", x, y)
        y = y - (widget:GetHeight() + 6)
        return widget
    end

    local function header(text)
        y = y - 8
        local h = CreateHeader(content, text)
        h:SetPoint("TOPLEFT", x, y)
        y = y - 22
        local line = content:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 0.82, 0, 0.3)
        line:SetHeight(1)
        line:SetPoint("LEFT", x, y + 4)
        line:SetPoint("RIGHT", -10, y + 4)
        y = y - 4
    end

    -- ============= PROFILES =============
    header("Profiles")

    local profileDD = CreateFrame("Frame", "BBHB_ProfileDD", content, "UIDropDownMenuTemplate")
    profileDD:SetPoint("TOPLEFT", x - 16, y)
    UIDropDownMenu_SetWidth(profileDD, 180)

    local function refreshProfileDD()
        UIDropDownMenu_Initialize(profileDD, function(self, level)
            for _, name in ipairs(BBHB:GetProfileNames()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.value = name
                info.func = function()
                    BBHB:SwitchProfile(name)
                    UIDropDownMenu_SetSelectedValue(profileDD, name)
                    UIDropDownMenu_SetText(profileDD, name)
                    BBHB:RefreshOptionsUI()
                end
                info.checked = (BetterBossHealthBarDB.currentProfile == name)
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        UIDropDownMenu_SetSelectedValue(profileDD, BetterBossHealthBarDB.currentProfile)
        UIDropDownMenu_SetText(profileDD, BetterBossHealthBarDB.currentProfile)
    end
    panel._refreshProfileDD = refreshProfileDD

    y = y - 32

    local newBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    newBox:SetSize(160, 22)
    newBox:SetPoint("TOPLEFT", x + 6, y)
    newBox:SetAutoFocus(false)
    newBox:SetMaxLetters(32)
    newBox:SetText("")

    local createBtn = CreateButton(content, "New Profile", function()
        local name = newBox:GetText() or ""
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return end
        if BBHB:CreateProfile(name) then
            BBHB:SwitchProfile(name)
            refreshProfileDD()
            BBHB:RefreshOptionsUI()
            newBox:SetText("")
            BBHB:Print("Created profile '" .. name .. "'.")
        else
            BBHB:Print("Profile name invalid or already exists.")
        end
    end)
    createBtn:SetPoint("TOPLEFT", newBox, "TOPRIGHT", 6, 0)

    local copyBtn = CreateButton(content, "Copy Current", function()
        local name = newBox:GetText() or ""
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return end
        if BBHB:CopyProfileFrom(BetterBossHealthBarDB.currentProfile, name) then
            BBHB:SwitchProfile(name)
            refreshProfileDD()
            BBHB:RefreshOptionsUI()
            newBox:SetText("")
            BBHB:Print("Profile copied as '" .. name .. "'.")
        end
    end)
    copyBtn:SetPoint("TOPLEFT", createBtn, "TOPRIGHT", 6, 0)

    y = y - 30

    local delBtn = CreateButton(content, "Delete Profile", function()
        local name = BetterBossHealthBarDB.currentProfile
        if BBHB:DeleteProfile(name) then
            BBHB:SwitchProfile("Default")
            refreshProfileDD()
            BBHB:RefreshOptionsUI()
            BBHB:Print("Deleted profile '" .. name .. "'.")
        else
            BBHB:Print("Cannot delete this profile.")
        end
    end)
    delBtn:SetPoint("TOPLEFT", x + 6, y)

    local resetBtn = CreateButton(content, "Reset to Default", function()
        BBHB:ResetProfile()
        BBHB:RefreshOptionsUI()
        BBHB:Print("Profile reset.")
    end)
    resetBtn:SetPoint("TOPLEFT", delBtn, "TOPRIGHT", 6, 0)

    y = y - 30

    -- ============= BAR SETTINGS =============
    header("Bar Appearance")

    local function barCfg() return BBHB:GetProfile().bar end

    place(CreateCheckbox(content, "Lock bars (hide drag anchor)",
        function() return barCfg().locked end,
        function(v)
            barCfg().locked = v
            BBHB.testMode = not v
        end))

    place(CreateSlider(content, "Width", 100, 600, 5,
        function() return barCfg().width end,
        function(v) barCfg().width = v end))

    place(CreateSlider(content, "Height", 8, 60, 1,
        function() return barCfg().height end,
        function(v) barCfg().height = v end))

    place(CreateSlider(content, "Spacing", 0, 30, 1,
        function() return barCfg().spacing end,
        function(v) barCfg().spacing = v end))

    place(CreateSlider(content, "Font Size", 8, 24, 1,
        function() return barCfg().fontSize end,
        function(v) barCfg().fontSize = v end))

    place(CreateDropdown(content, "Grow Direction", {
        { text = "Down", value = "DOWN" },
        { text = "Up",   value = "UP" },
    },  function() return barCfg().growDirection end,
        function(v) barCfg().growDirection = v end))

    place(CreateColorSwatch(content, "Bar Color",
        function() return barCfg().color end,
        function(c) barCfg().color = c end))

    place(CreateColorSwatch(content, "Background Color",
        function() return barCfg().bgColor end,
        function(c) barCfg().bgColor = c end))

    place(CreateColorSwatch(content, "Border Color",
        function() return barCfg().borderColor end,
        function(c) barCfg().borderColor = c end))

    place(CreateColorSwatch(content, "Text Color",
        function() return barCfg().textColor end,
        function(c) barCfg().textColor = c end))

    -- ============= BOSS NAME / PERCENT =============
    header("Boss Name & Percent")

    place(CreateCheckbox(content, "Show Percent",
        function() return barCfg().showPercent end,
        function(v) barCfg().showPercent = v end))

    place(CreateCheckbox(content, "Show Boss Name",
        function() return barCfg().showBossName end,
        function(v) barCfg().showBossName = v end))

    place(CreateDropdown(content, "Boss Name Position", {
        { text = "Inside the bar", value = "INSIDE" },
        { text = "Above the bar",  value = "ABOVE" },
        { text = "Below the bar",  value = "BELOW" },
    },  function() return barCfg().bossNamePosition end,
        function(v) barCfg().bossNamePosition = v end))

    place(CreateDropdown(content, "Boss Name Alignment", {
        { text = "Left",   value = "LEFT" },
        { text = "Center", value = "CENTER" },
        { text = "Right",  value = "RIGHT" },
    },  function() return barCfg().bossNameAlign end,
        function(v) barCfg().bossNameAlign = v end))

    -- ============= CAST BAR =============
    header("Cast Bar")

    local function castCfg() return BBHB:GetProfile().cast end

    place(CreateCheckbox(content, "Show Cast Bar",
        function() return castCfg().enabled end,
        function(v) castCfg().enabled = v end))

    place(CreateCheckbox(content, "Show Spell Name",
        function() return castCfg().showSpellName end,
        function(v) castCfg().showSpellName = v end))

    place(CreateCheckbox(content, "Show Cast Time",
        function() return castCfg().showCastTime end,
        function(v) castCfg().showCastTime = v end))

    place(CreateCheckbox(content, "Large Spell Icon (left of bar)",
        function() return castCfg().bigIcon end,
        function(v) castCfg().bigIcon = v end))

    place(CreateSlider(content, "Cast Bar Height", 6, 40, 1,
        function() return castCfg().height end,
        function(v) castCfg().height = v end))

    place(CreateSlider(content, "Cast Bar Font Size", 7, 22, 1,
        function() return castCfg().fontSize end,
        function(v) castCfg().fontSize = v end))

    place(CreateColorSwatch(content, "Color - Kickable (interruptible)",
        function() return castCfg().kickableColor end,
        function(c) castCfg().kickableColor = c end))

    place(CreateColorSwatch(content, "Color - NOT Kickable",
        function() return castCfg().notKickableColor end,
        function(c) castCfg().notKickableColor = c end))

    place(CreateColorSwatch(content, "Cast Bar Background",
        function() return castCfg().bgColor end,
        function(c) castCfg().bgColor = c end))

    place(CreateColorSwatch(content, "Cast Bar Text Color",
        function() return castCfg().textColor end,
        function(c) castCfg().textColor = c end))

    -- ============= MAJOR SPELLS =============
    header("Major Spells Panel (right side)")

    local function majorCfg() return BBHB:GetProfile().majorSpells end

    place(CreateCheckbox(content, "Show Major Spells Panel",
        function() return majorCfg().enabled end,
        function(v) majorCfg().enabled = v end))

    place(CreateCheckbox(content, "Show Spell Name",
        function() return majorCfg().showName end,
        function(v) majorCfg().showName = v end))

    place(CreateCheckbox(content, "Show Time",
        function() return majorCfg().showTime end,
        function(v) majorCfg().showTime = v end))

    place(CreateSlider(content, "Icon Size", 14, 64, 1,
        function() return majorCfg().iconSize end,
        function(v) majorCfg().iconSize = v end))

    place(CreateSlider(content, "Font Size", 8, 24, 1,
        function() return majorCfg().fontSize end,
        function(v) majorCfg().fontSize = v end))

    place(CreateSlider(content, "Max Visible", 1, 10, 1,
        function() return majorCfg().maxShown end,
        function(v) majorCfg().maxShown = v end))

    place(CreateSlider(content, "Warning Threshold (s)", 0, 30, 1,
        function() return majorCfg().warningThreshold end,
        function(v) majorCfg().warningThreshold = v end))

    place(CreateSlider(content, "X Offset from bars", -400, 400, 1,
        function() return majorCfg().offsetX end,
        function(v) majorCfg().offsetX = v end))

    place(CreateSlider(content, "Y Offset from bars", -400, 400, 1,
        function() return majorCfg().offsetY end,
        function(v) majorCfg().offsetY = v end))

    place(CreateColorSwatch(content, "Text Color",
        function() return majorCfg().color end,
        function(c) majorCfg().color = c end))

    place(CreateColorSwatch(content, "Warning Color",
        function() return majorCfg().warningColor end,
        function(c) majorCfg().warningColor = c end))

    place(CreateColorSwatch(content, "Row Background",
        function() return majorCfg().bgColor end,
        function(c) majorCfg().bgColor = c end))

    local helpFs = CreateLabel(content, "Use: /bbhb timer <seconds> <name>  -  /bbhb cleartimers", 10)
    helpFs:SetPoint("TOPLEFT", x + 6, y - 6)
    helpFs:SetTextColor(0.7, 0.7, 0.7)
    y = y - 22

    -- ============= TEST =============
    header("Preview")
    local testBtn = CreateButton(content, "Toggle Test Mode", function()
        BBHB:ToggleTestMode()
    end)
    testBtn:SetPoint("TOPLEFT", x + 6, y)
    testBtn:SetWidth(160)
    y = y - 30

    content:SetHeight(math.abs(y) + 40)

    -- Register with Settings API (appears in Settings > AddOns)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Better Boss Health Bar")
        Settings.RegisterAddOnCategory(category)
        BBHB._settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function BBHB:RefreshOptionsUI()
    if panel and panel._refreshProfileDD then panel._refreshProfileDD() end
    for _, w in ipairs(widgets) do
        if w._refresh then w._refresh() end
    end
end

function BBHB:OpenOptions()
    if not panel then BBHB:BuildOptions() end
    BBHB:RefreshOptionsUI()
    local cat = BBHB._settingsCategory
    if Settings and Settings.OpenToCategory and cat then
        local id = cat.GetID and cat:GetID() or cat.ID
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
