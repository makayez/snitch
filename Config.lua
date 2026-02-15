-- Config.lua - Configuration panel

Snitch = Snitch or {}
Snitch.Config = {}

local Config = Snitch.Config

-- ============================================================================
-- Localize Globals (Performance)
-- ============================================================================

local _G = _G
local pairs = pairs
local type = type
local CreateFrame = CreateFrame
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local PlaySound = PlaySound

-- ============================================================================
-- Constants
-- ============================================================================

local CONFIG_PANEL_WIDTH = 600
local CONFIG_PANEL_HEIGHT = 500

-- Sound effect options
local SOUND_OPTIONS = {
    {text = "Raid Warning", value = SOUNDKIT.RAID_WARNING or 8959},
    {text = "Ready Check", value = SOUNDKIT.READY_CHECK or 8960},
    {text = "Alarm Clock", value = SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12867},
    {text = "Level Up", value = SOUNDKIT.LEVEL_UP or 888},
    {text = "Achievement", value = SOUNDKIT.ACHIEVEMENT_MENU_OPEN or 3337},
}

-- ============================================================================
-- Panel Creation
-- ============================================================================

local function CreateConfigPanel()
    local panel = CreateFrame("Frame", "SnitchConfigPanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(CONFIG_PANEL_WIDTH, CONFIG_PANEL_HEIGHT)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    panel.title:SetPoint("TOP", 0, -5)
    panel.title:SetText("Snitch Configuration")

    local yOffset = -40

    -- Global Enable
    local enableCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    enableCheckbox.text = enableCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheckbox.text:SetPoint("LEFT", enableCheckbox, "RIGHT", 5, 0)
    enableCheckbox.text:SetText("Enable Snitch")
    enableCheckbox:SetChecked(SnitchDB.enabled)
    enableCheckbox:SetScript("OnClick", function(self)
        SnitchDB.enabled = self:GetChecked()
    end)
    yOffset = yOffset - 40

    -- Divider
    local divider1 = panel:CreateTexture(nil, "ARTWORK")
    divider1:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    divider1:SetSize(560, 1)
    divider1:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 20

    -- Info text
    local infoLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    infoLabel:SetPoint("TOPLEFT", 20, yOffset)
    infoLabel:SetPoint("TOPRIGHT", -20, yOffset)
    infoLabel:SetJustifyH("LEFT")
    infoLabel:SetText("Each module has its own alert settings. Click 'Configure...' next to a module to customize its alerts.")
    yOffset = yOffset - 40

    -- Divider
    local divider2 = panel:CreateTexture(nil, "ARTWORK")
    divider2:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    divider2:SetSize(560, 1)
    divider2:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 20

    -- Module Settings
    local moduleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    moduleLabel:SetPoint("TOPLEFT", 20, yOffset)
    moduleLabel:SetText("Modules:")
    yOffset = yOffset - 30

    -- Add checkbox and configure button for each module
    for moduleId, module in pairs(Snitch.modules) do
        local moduleCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        moduleCheckbox:SetPoint("TOPLEFT", 30, yOffset)
        moduleCheckbox.text = moduleCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        moduleCheckbox.text:SetPoint("LEFT", moduleCheckbox, "RIGHT", 5, 0)
        moduleCheckbox.text:SetText(module.name)

        local moduleSettings = SnitchDB.modules[moduleId]
        moduleCheckbox:SetChecked(moduleSettings and moduleSettings.enabled)
        moduleCheckbox:SetScript("OnClick", function(self)
            if not SnitchDB.modules[moduleId] then
                SnitchDB.modules[moduleId] = {}
            end
            SnitchDB.modules[moduleId].enabled = self:GetChecked()
        end)

        -- Configure button
        local configBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        configBtn:SetSize(100, 25)
        configBtn:SetPoint("LEFT", moduleCheckbox.text, "RIGHT", 10, 0)
        configBtn:SetText("Configure...")
        configBtn:SetScript("OnClick", function()
            if Snitch.Config.ShowModuleConfig then
                Snitch.Config:ShowModuleConfig(moduleId, module.name)
            end
        end)

        -- Description
        if module.description then
            local descLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            descLabel:SetPoint("TOPLEFT", 50, yOffset - 20)
            descLabel:SetPoint("TOPRIGHT", -30, yOffset - 20)
            descLabel:SetJustifyH("LEFT")
            descLabel:SetText(module.description)
            yOffset = yOffset - 50
        else
            yOffset = yOffset - 35
        end
    end

    return panel
end

-- ============================================================================
-- Panel Management
-- ============================================================================

Config.frame = nil

function Config:Show()
    if not self.frame then
        self.frame = CreateConfigPanel()
    end
    self.frame:Show()
end

function Config:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Config:Toggle()
    if not self.frame then
        self:Show()
        return
    end

    if self.frame:IsVisible() then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================================
-- Per-Module Configuration
-- ============================================================================

Config.moduleConfigFrames = {}

function Config:ShowModuleConfig(moduleId, moduleName)
    local frameKey = "module_" .. moduleId

    if self.moduleConfigFrames[frameKey] and self.moduleConfigFrames[frameKey]:IsVisible() then
        self.moduleConfigFrames[frameKey]:Hide()
        return
    end

    if not self.moduleConfigFrames[frameKey] then
        self.moduleConfigFrames[frameKey] = self:CreateModuleConfigPanel(moduleId, moduleName)
    end

    self.moduleConfigFrames[frameKey]:Show()
end

function Config:CreateModuleConfigPanel(moduleId, moduleName)
    local panel = CreateFrame("Frame", "SnitchModuleConfig_" .. moduleId, UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(500, 450)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(200)
    panel:Hide()

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    panel.title:SetPoint("TOP", 0, -5)
    panel.title:SetText(moduleName .. " - Alert Configuration")

    local yOffset = -40

    -- Get module settings
    local moduleSettings = SnitchDB.modules[moduleId]
    if not moduleSettings or not moduleSettings.alerts then
        return panel
    end

    local alerts = moduleSettings.alerts

    -- Info text
    local infoLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    infoLabel:SetPoint("TOPLEFT", 20, yOffset)
    infoLabel:SetPoint("TOPRIGHT", -20, yOffset)
    infoLabel:SetJustifyH("LEFT")
    infoLabel:SetText("Configure how this module sends alerts. Each module can have different alert settings.")
    yOffset = yOffset - 35

    -- Console output
    local consoleCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    consoleCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    consoleCheckbox.text = consoleCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    consoleCheckbox.text:SetPoint("LEFT", consoleCheckbox, "RIGHT", 5, 0)
    consoleCheckbox.text:SetText("Console output")
    consoleCheckbox:SetChecked(alerts.console)
    consoleCheckbox:SetScript("OnClick", function(self)
        alerts.console = self:GetChecked()
    end)
    yOffset = yOffset - 35

    -- Chat message
    local chatCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    chatCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    chatCheckbox.text = chatCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chatCheckbox.text:SetPoint("LEFT", chatCheckbox, "RIGHT", 5, 0)
    chatCheckbox.text:SetText("Chat message")
    chatCheckbox:SetChecked(alerts.chat)
    chatCheckbox:SetScript("OnClick", function(self)
        alerts.chat = self:GetChecked()
    end)
    yOffset = yOffset - 35

    -- Chat type dropdown
    local chatTypeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chatTypeLabel:SetPoint("TOPLEFT", 40, yOffset)
    chatTypeLabel:SetText("Chat type:")

    local chatTypeDropdown = CreateFrame("Frame", "SnitchModuleChatTypeDropdown_" .. moduleId, panel, "UIDropDownMenuTemplate")
    chatTypeDropdown:SetPoint("TOPLEFT", 110, yOffset + 5)
    UIDropDownMenu_SetWidth(chatTypeDropdown, 120)

    local chatTypes = {
        {text = "Say", value = "SAY"},
        {text = "Party", value = "PARTY"},
        {text = "Raid", value = "RAID"}
    }

    UIDropDownMenu_Initialize(chatTypeDropdown, function(self, level)
        for _, option in ipairs(chatTypes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                alerts.chatType = option.value
                UIDropDownMenu_SetText(chatTypeDropdown, option.text)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Set initial chat type
    local currentChatType = "Party"
    for _, option in ipairs(chatTypes) do
        if option.value == alerts.chatType then
            currentChatType = option.text
            break
        end
    end
    UIDropDownMenu_SetText(chatTypeDropdown, currentChatType)
    yOffset = yOffset - 45

    -- Audio alert
    local audioCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    audioCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    audioCheckbox.text = audioCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    audioCheckbox.text:SetPoint("LEFT", audioCheckbox, "RIGHT", 5, 0)
    audioCheckbox.text:SetText("Audio alert")
    audioCheckbox:SetChecked(alerts.audio)
    audioCheckbox:SetScript("OnClick", function(self)
        alerts.audio = self:GetChecked()
    end)
    yOffset = yOffset - 35

    -- Audio dropdown
    local audioLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    audioLabel:SetPoint("TOPLEFT", 40, yOffset)
    audioLabel:SetText("Sound:")

    local audioDropdown = CreateFrame("Frame", "SnitchModuleAudioDropdown_" .. moduleId, panel, "UIDropDownMenuTemplate")
    audioDropdown:SetPoint("TOPLEFT", 110, yOffset + 5)
    UIDropDownMenu_SetWidth(audioDropdown, 150)

    UIDropDownMenu_Initialize(audioDropdown, function(self, level)
        for _, option in ipairs(SOUND_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                alerts.audioFile = option.value
                UIDropDownMenu_SetText(audioDropdown, option.text)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Set initial audio
    local currentSound = "Raid Warning"
    for _, option in ipairs(SOUND_OPTIONS) do
        if option.value == alerts.audioFile then
            currentSound = option.text
            break
        end
    end
    UIDropDownMenu_SetText(audioDropdown, currentSound)

    -- Test sound button
    local testSoundBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testSoundBtn:SetSize(60, 25)
    testSoundBtn:SetPoint("LEFT", audioDropdown, "RIGHT", -15, -2)
    testSoundBtn:SetText("Test")
    testSoundBtn:SetScript("OnClick", function()
        PlaySound(alerts.audioFile)
    end)
    yOffset = yOffset - 45

    -- Screen warning
    local screenCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    screenCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    screenCheckbox.text = screenCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    screenCheckbox.text:SetPoint("LEFT", screenCheckbox, "RIGHT", 5, 0)
    screenCheckbox.text:SetText("Screen warning")
    screenCheckbox:SetChecked(alerts.screen)
    screenCheckbox:SetScript("OnClick", function(self)
        alerts.screen = self:GetChecked()
    end)

    -- Configure screen appearance button
    local configScreenBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    configScreenBtn:SetSize(120, 25)
    configScreenBtn:SetPoint("LEFT", screenCheckbox.text, "RIGHT", 10, 0)
    configScreenBtn:SetText("Appearance...")
    configScreenBtn:SetScript("OnClick", function()
        if Snitch.Config.ShowScreenAlertConfig then
            Snitch.Config:ShowScreenAlertConfig()
        end
    end)
    yOffset = yOffset - 50

    -- Help text
    local helpText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", 20, yOffset)
    helpText:SetPoint("TOPRIGHT", -20, yOffset)
    helpText:SetJustifyH("LEFT")
    helpText:SetSpacing(2)
    helpText:SetText(
        "Screen warning appearance (font, size, position) is configured globally " ..
        "using the 'Appearance...' button above. Each module controls whether to show screen warnings."
    )

    return panel
end

-- ============================================================================
-- Screen Alert Configuration
-- ============================================================================

Config.screenAlertFrame = nil

function Config:ShowScreenAlertConfig()
    if self.screenAlertFrame and self.screenAlertFrame:IsVisible() then
        self.screenAlertFrame:Hide()
        return
    end

    if not self.screenAlertFrame then
        self.screenAlertFrame = self:CreateScreenAlertConfigPanel()
    end

    self.screenAlertFrame:Show()
end

function Config:CreateScreenAlertConfigPanel()
    local panel = CreateFrame("Frame", "SnitchScreenAlertConfigPanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(500, 450)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(200)  -- Above main config panel
    panel:Hide()

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    panel.title:SetPoint("TOP", 0, -5)
    panel.title:SetText("Screen Alert Configuration")

    local yOffset = -40

    -- Font selection
    local fontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fontLabel:SetPoint("TOPLEFT", 20, yOffset)
    fontLabel:SetText("Font:")
    yOffset = yOffset - 25

    local fontDropdown = CreateFrame("Frame", "SnitchScreenAlertFontDropdown", panel, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", 20, yOffset + 5)
    UIDropDownMenu_SetWidth(fontDropdown, 200)

    UIDropDownMenu_Initialize(fontDropdown, function(self, level)
        local fonts = Snitch.ScreenAlert and Snitch.ScreenAlert.FONTS or {}
        for i, font in ipairs(fonts) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = font.name
            info.value = i
            info.func = function()
                SnitchDB.screenAlert.font = i
                UIDropDownMenu_SetText(fontDropdown, font.name)
                if Snitch.ScreenAlert then
                    Snitch.ScreenAlert:ApplySettings()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Set initial font
    local fonts = Snitch.ScreenAlert and Snitch.ScreenAlert.FONTS or {}
    local currentFont = fonts[SnitchDB.screenAlert.font] or fonts[1]
    if currentFont then
        UIDropDownMenu_SetText(fontDropdown, currentFont.name)
    end
    yOffset = yOffset - 45

    -- Font size slider
    local sizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sizeLabel:SetPoint("TOPLEFT", 20, yOffset)
    sizeLabel:SetText("Font Size:")
    yOffset = yOffset - 25

    local sizeSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 20, yOffset)
    sizeSlider:SetWidth(400)
    sizeSlider:SetMinMaxValues(16, 72)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetValue(SnitchDB.screenAlert.fontSize)
    sizeSlider:SetObeyStepOnDrag(true)

    sizeSlider.Low:SetText("16")
    sizeSlider.High:SetText("72")

    sizeSlider.valueText = sizeSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeSlider.valueText:SetPoint("TOP", sizeSlider, "BOTTOM", 0, 0)
    sizeSlider.valueText:SetText(SnitchDB.screenAlert.fontSize)

    sizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        SnitchDB.screenAlert.fontSize = value
        self.valueText:SetText(value)
        if Snitch.ScreenAlert then
            Snitch.ScreenAlert:ApplySettings()
        end
    end)
    yOffset = yOffset - 50

    -- Duration slider
    local durationLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    durationLabel:SetPoint("TOPLEFT", 20, yOffset)
    durationLabel:SetText("Display Duration:")
    yOffset = yOffset - 25

    local durationSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    durationSlider:SetPoint("TOPLEFT", 20, yOffset)
    durationSlider:SetWidth(400)
    durationSlider:SetMinMaxValues(1, 10)
    durationSlider:SetValueStep(0.5)
    durationSlider:SetValue(SnitchDB.screenAlert.duration)
    durationSlider:SetObeyStepOnDrag(true)

    durationSlider.Low:SetText("1s")
    durationSlider.High:SetText("10s")

    durationSlider.valueText = durationSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    durationSlider.valueText:SetPoint("TOP", durationSlider, "BOTTOM", 0, 0)
    durationSlider.valueText:SetText(SnitchDB.screenAlert.duration .. "s")

    durationSlider:SetScript("OnValueChanged", function(self, value)
        SnitchDB.screenAlert.duration = value
        self.valueText:SetText(string.format("%.1fs", value))
    end)
    yOffset = yOffset - 50

    -- Background checkbox
    local bgCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    bgCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    bgCheckbox.text = bgCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgCheckbox.text:SetPoint("LEFT", bgCheckbox, "RIGHT", 5, 0)
    bgCheckbox.text:SetText("Show background")
    bgCheckbox:SetChecked(SnitchDB.screenAlert.showBackground)
    bgCheckbox:SetScript("OnClick", function(self)
        SnitchDB.screenAlert.showBackground = self:GetChecked()
        if Snitch.ScreenAlert then
            Snitch.ScreenAlert:ApplySettings()
        end
    end)
    yOffset = yOffset - 40

    -- Position button
    local positionBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    positionBtn:SetSize(150, 30)
    positionBtn:SetPoint("TOPLEFT", 20, yOffset)
    positionBtn:SetText("Reposition Alert")

    local isDragMode = false
    positionBtn:SetScript("OnClick", function(self)
        if not Snitch.ScreenAlert then return end

        isDragMode = not isDragMode
        if isDragMode then
            Snitch.ScreenAlert:EnableDragMode()
            self:SetText("Done Repositioning")
        else
            Snitch.ScreenAlert:DisableDragMode()
            self:SetText("Reposition Alert")
        end
    end)
    yOffset = yOffset - 40

    -- Test button
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(150, 30)
    testBtn:SetPoint("TOPLEFT", 180, yOffset + 40)
    testBtn:SetText("Test Alert")
    testBtn:SetScript("OnClick", function()
        if Snitch.ScreenAlert then
            Snitch.ScreenAlert:Show("This is a test alert!\nResize and reposition as needed.")
        end
    end)

    -- Help text
    local helpText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", 20, yOffset)
    helpText:SetPoint("TOPRIGHT", -20, yOffset)
    helpText:SetJustifyH("LEFT")
    helpText:SetSpacing(2)
    helpText:SetText(
        "Use 'Reposition Alert' to drag the alert to your preferred location. " ..
        "Click 'Test Alert' to preview your changes. " ..
        "All changes are saved automatically."
    )

    -- Close when pressing Escape
    panel:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)

    return panel
end

-- ============================================================================
-- Interface Options Registration
-- ============================================================================

function Config:RegisterInterfaceOptions()
    local settingsPanel = CreateFrame("Frame", "SnitchSettingsPanel")
    settingsPanel.name = "Snitch"

    local title = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Snitch")

    local desc = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -16, -32)
    desc:SetJustifyH("LEFT")
    desc:SetText("Alerts when group members perform certain actions like using SwapBlaster, having low durability, or other configurable behaviors.")

    local openBtn = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    openBtn:SetSize(180, 30)
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openBtn:SetText("Open Configuration")
    openBtn:SetScript("OnClick", function()
        Config:Show()
        Settings.Close()
    end)

    local slashInfo = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slashInfo:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -16)
    slashInfo:SetText("You can also use the slash command: /snitch")

    local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, "Snitch")
    Settings.RegisterAddOnCategory(category)
    self.category = category
end
