local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local FontList = require("fontlist")
local Notification = require("ui/widget/notification")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local ArabicEnhancement = WidgetContainer:extend{
    name = "arabic_enhancement",
    is_doc_only = false,
}

local function getAvailableFonts()
    local fonts = {}
    local ok, face_list = pcall(function() return FontList:getFontList() end)

    if ok and type(face_list) == "table" then
        for _, face in ipairs(face_list) do
            table.insert(fonts, { text = face, face = face })
        end
    end

    table.sort(fonts, function(a, b) return a.text:lower() < b.text:lower() end)

    if #fonts == 0 then
        table.insert(fonts, { text = _("System Default"), face = "" })
    end

    return fonts
end

local ARABIC_RANGES = {
    { 0x0600, 0x06FF },
    { 0x0750, 0x077F },
    { 0x08A0, 0x08FF },
    { 0xFB50, 0xFDFF },
    { 0xFE70, 0xFEFF },
}

local function isArabicCodepoint(cp)
    for _, range in ipairs(ARABIC_RANGES) do
        if cp >= range[1] and cp <= range[2] then
            return true
        end
    end
    return false
end

local function isArabicString(str)
    if type(str) ~= "string" or str == "" then return false end

    if utf8 and utf8.codepoint then
        local ok = pcall(function()
            for _, cp in utf8.codes(str) do
                if isArabicCodepoint(cp) then
                    error("found", 0)
                end
            end
        end)
        if not ok then return true end
        return false
    end

    local len = #str
    local i = 1
    while i <= len do
        local b1 = string.byte(str, i)
        local cp, nbytes

        if b1 < 0x80 then
            cp, nbytes = b1, 1
        elseif b1 >= 0xC0 and b1 < 0xE0 and (i + 1) <= len then
            local b2 = string.byte(str, i + 1)
            cp = ((b1 - 0xC0) * 0x40) + (b2 - 0x80)
            nbytes = 2
        elseif b1 >= 0xE0 and b1 < 0xF0 and (i + 2) <= len then
            local b2, b3 = string.byte(str, i + 1), string.byte(str, i + 2)
            cp = ((b1 - 0xE0) * 0x1000) + ((b2 - 0x80) * 0x40) + (b3 - 0x80)
            nbytes = 3
        else
            cp, nbytes = 0, 1
        end

        if isArabicCodepoint(cp) then
            return true
        end
        i = i + nbytes
    end
    return false
end

local ARABIC_VARIANT_CODES = {
    ar = true, arb = true, arz = true, acm = true, acq = true,
    acw = true, acx = true, acy = true, adf = true, aeb = true,
    aec = true, afb = true, apc = true, apd = true, arq = true,
    ars = true, ary = true, ayh = true, ayl = true,
    ayn = true, ayp = true, shu = true, ssh = true,
}

local function isArabicLangCode(lang)
    if not lang or lang == "" then return false end
    lang = lang:lower()

    local code = lang:match("^([%a]+)")
    if code and ARABIC_VARIANT_CODES[code] then
        return true
    end
    if lang:find("arabic") then return true end
    return false
end

function ArabicEnhancement:isArabicBook()
    local doc = self.ui.document
    if not doc then return false end

    local ok, props = pcall(function() return doc:getProps() end)
    if ok and props then
        if isArabicLangCode(props.language or props.lang) then
            return true
        end
        if isArabicString(props.title)
           or isArabicString(props.authors)
           or isArabicString(props.keywords)
           or isArabicString(props.description) then
            return true
        end
    end

    local ok_toc, toc = pcall(function() return doc:getTOC() end)
    if ok_toc and type(toc) == "table" then
        local count = 0
        local function scanTOC(items)
            for _, item in ipairs(items) do
                count = count + 1
                if count > 20 then return false end
                if item.title and isArabicString(item.title) then
                    return true
                end
                if item.subitems and scanTOC(item.subitems) then
                    return true
                end
            end
            return false
        end
        if scanTOC(toc) then return true end
    end

    local ok_file, filepath = pcall(function() return doc.file end)
    if ok_file and isArabicString(filepath) then return true end

    return false
end

function ArabicEnhancement:applyArabicSettings()
    local ui = self.ui
    if not ui or not ui.doc_settings then return end

    ui.doc_settings:saveSetting("inverse_reading_order", 1)

    if ui.paging then
        ui.paging.inverse_reading_order = true
        if ui.paging.recalculatePageTurnProperties then
            pcall(function() ui.paging:recalculatePageTurnProperties() end)
        end
    end
    if ui.setupTapTouchZones then
        pcall(function() ui.setupTapTouchZones() end)
    end

    local applied_font = nil
    local is_crengine = (ui.rolling ~= nil)

    if is_crengine then
        ui.rolling.inverse_reading_order = true

        if not ui.doc_settings:has("embedded_fonts") then
            ui.doc_settings:saveSetting("embedded_fonts", true)
        end

        if not ui.doc_settings:has("font_face") then
            applied_font = self.settings:readSetting("preferred_font")
            if applied_font and applied_font ~= "" then
                ui.doc_settings:saveSetting("font_face", applied_font)
            end
        end

        if self.settings:readSetting("auto_align_right") ~= false and not ui.doc_settings:has("text_align") then
            ui.doc_settings:saveSetting("text_align", "right")
        end

        if ui.view and ui.view.initFont then
            pcall(function() ui.view:initFont() end)
        end
        if ui.reinitDocumentView then
            pcall(function() ui.reinitDocumentView() end)
        end
    end

    ui.doc_settings:flush()

    if ui.view and ui.view.dialog and UIManager.setDirty then
        UIManager:setDirty(ui.view.dialog, "ui")
    end

    local msg = _("Arabic detected: RTL & Alignment enabled")
    if applied_font and applied_font ~= "" then
        msg = msg .. " (" .. applied_font .. ")"
    end
    UIManager:show(Notification:new{
        text = msg,
        timeout = 2.5,
    })
end

function ArabicEnhancement:onToggleArabicRTL()
    local ui = self.ui
    if not ui or not ui.doc_settings then return end

    local current = ui.doc_settings:readSetting("inverse_reading_order")
    local newval = (current and current ~= 0) and 0 or 1
    local is_crengine = (ui.rolling ~= nil)

    ui.doc_settings:saveSetting("inverse_reading_order", newval)

    if ui.paging then
        ui.paging.inverse_reading_order = (newval ~= 0)
        if ui.paging.recalculatePageTurnProperties then
            pcall(function() ui.paging:recalculatePageTurnProperties() end)
        end
    end
    if ui.setupTapTouchZones then
        pcall(function() ui.setupTapTouchZones() end)
    end

    if is_crengine then
        ui.rolling.inverse_reading_order = (newval ~= 0)

        if newval == 1 then
            ui.doc_settings:saveSetting("text_align", "right")
        else
            ui.doc_settings:delSetting("text_align")
        end
        if ui.reinitDocumentView then
            pcall(function() ui.reinitDocumentView() end)
        end
    end

    ui.doc_settings:flush()

    if ui.view and ui.view.dialog and UIManager.setDirty then
        UIManager:setDirty(ui.view.dialog, "ui")
    end

    UIManager:show(Notification:new{
        text = newval ~= 0 and _("RTL & Right Align enabled") or _("LTR enabled"),
        timeout = 2,
    })
end

function ArabicEnhancement:onReaderReady()
    UIManager:nextTick(function()
        if not self.ui or not self.ui.doc_settings then return end
        if self.settings:readSetting("auto_detect") == false then return end
        if self.ui.doc_settings:has("inverse_reading_order") then return end

        if self:isArabicBook() then
            self:applyArabicSettings()
        end
    end)
end

function ArabicEnhancement:init()
    self.settings = DataStorage:getSettings("arabic_enhancement")

    if not self.settings:has("preferred_font") then
        local dyn_fonts = getAvailableFonts()
        if #dyn_fonts > 0 then
            self.settings:saveSetting("preferred_font", dyn_fonts[1].face)
        end
    end

    if not self.settings:has("auto_detect") then
        self.settings:saveSetting("auto_detect", true)
    end

    if not self.settings:has("auto_align_right") then
        self.settings:saveSetting("auto_align_right", true)
    end

    self.settings:flush()

    Dispatcher:registerAction("arabic_enhancement_force", {
        category = "none",
        event = "ToggleArabicRTL",
        title = _("Arabic Enhancement: Toggle RTL direction"),
        general = true,
    })

    self.ui.menu:registerToMainMenu(self)
end

function ArabicEnhancement:addToMainMenu(menu_items)
    menu_items.arabic_enhancement_menu = {
        text = _("Arabic Enhancement"),
        sub_item_table = {
            {
                text = _("Auto-detect Arabic books"),
                checked_func = function()
                    return self.settings:readSetting("auto_detect") ~= false
                end,
                callback = function()
                    local cur = self.settings:readSetting("auto_detect") ~= false
                    self.settings:saveSetting("auto_detect", not cur)
                    self.settings:flush()
                end,
            },
            {
                text = _("Auto-align text to right"),
                checked_func = function()
                    return self.settings:readSetting("auto_align_right") ~= false
                end,
                callback = function()
                    local cur = self.settings:readSetting("auto_align_right") ~= false
                    self.settings:saveSetting("auto_align_right", not cur)
                    self.settings:flush()
                end,
            },
            {
                text = _("Toggle RTL for current book"),
                keep_menu_open = true,
                callback = function()
                    self:onToggleArabicRTL()
                end,
            },
            {
                text = _("Fallback Arabic Font"),
                sub_item_table = function()
                    local items = {}
                    local current = self.settings:readSetting("preferred_font")
                    local dynamic_fonts = getAvailableFonts()

                    for _, f in ipairs(dynamic_fonts) do
                        table.insert(items, {
                            text = f.text,
                            checked = (current == f.face),
                            callback = function()
                                self.settings:saveSetting("preferred_font", f.face)
                                self.settings:flush()
                                UIManager:show(Notification:new{
                                    text = _("Fallback font set to: ") .. f.text,
                                    timeout = 2,
                                })
                            end,
                        })
                    end
                    return items
                end,
            },
        },
    }
end

return ArabicEnhancement
