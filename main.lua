local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local LuaSettings = require("luasettings")
local lfs = require("libs/libkoreader-lfs")
local gettext = require("gettext")

local TRANSLATIONS_AR = {
    ["Arabic Enhancement"] = "تحسينات اللغة العربية",
    ["Auto-detect Arabic books"] = "اكتشاف الكتب العربية تلقائياً",
    ["Auto-detect and switch to RTL for Arabic books"] = "اكتشاف الكتب العربية وتفعيل التقليب من اليمين لليسار تلقائياً",
    ["Apply Arabic style to this book"] = "تطبيق ستايل القراءة العربي على هذا الكتاب",
    ["Manually sets RTL (Fonts/Align ignored for PDF)"] = "تطبيق يدوي لليمين لليسار (يتم تجاهل الخط والمحاذاة لـ PDF)",
    ["Toggle right-to-left for this book"] = "تبديل اتجاه التقليب لهذا الكتاب",
    ["Reverse page order for this book"] = "عكس ترتيب صفحات هذا الكتاب",
    ["Auto-align text to the right"] = "محاذاة النص لليمين تلقائياً",
    ["Auto-disable hyphenation"] = "تعطيل فواصل الكلمات اللاتينية تلقائياً",
    ["Auto line-height (130%)"] = "ضبط تباعد الأسطر تلقائياً (130%)",
    ["Enhanced dictionary lookup"] = "تحسين البحث في القاموس (إزالة التشكيل)",
    ["Clean Arabic clippings (RLM)"] = "حفظ علامات الترقيم في المقتبسات (RLM)",
    ["Not available for PDF files"] = "غير متاح لملفات PDF",
    ["Not available for this document type"] = "غير متاح لهذا المستند",
    ["Default fallback font"] = "الخط العربي المعتمد",
    ["Select fallback font from bundled assets"] = "اختيار الخط الافتراضي (شهرزاد / أميري / كايرو)",
    ["No document open"] = "لا يوجد كتاب مفتوح",
    ["Right-to-left enabled"] = "تم تفعيل التقليب من اليمين لليسار",
    ["Left-to-right enabled"] = "تم تفعيل التقليب من اليسار لليمين",
    ["Page order reversed"] = "تم عكس ترتيب الصفحات",
    ["Original page order restored"] = "تمت استعادة الترتيب الأصلي للصفحات",
    ["Arabic book detected — Arabic reading style applied (RTL)"] = "تم اكتشاف كتاب عربي — تم تطبيق ستايل القراءة العربي (RTL)",
    ["Arabic book detected — Arabic reading style applied"] = "تم اكتشاف كتاب عربي — تم تطبيق ستايل القراءة العربي",
    ["Arabic style applied (PDF: RTL page-turning only)"] = "تم تطبيق الستايل العربي (PDF: تقليب الصفحات فقط)",
    ["Arabic style applied — RTL enabled"] = "تم تطبيق الستايل العربي — القراءة من اليمين لليسار",
    ["Font set system-wide to: "] = "تم تعيين الخط على مستوى كوريدر إلى: ",
    ["Arabic Enhancement: apply Arabic style to current book"] = "تحسينات العربية: تطبيق النمط العربي على الكتاب الحالي",
    ["Arabic Enhancement: toggle RTL for this book"] = "تحسينات العربية: تبديل اتجاه القراءة لهذا الكتاب",
}

local BUNDLED_FONTS = {
    { name = "Scheherazade New", face = "Scheherazade New" },
    { name = "Amiri", face = "Amiri" },
    { name = "Cairo", face = "Cairo" },
}

local function isArabicUI()
    local lang = nil
    if G_reader_settings then
        lang = G_reader_settings:readSetting("language")
    end
    if not lang then
        pcall(function()
            local s = LuaSettings:open(DataStorage:getSettingsDir() .. "/settings.reader.lua")
            if s then lang = s:readSetting("language") end
        end)
    end
    return type(lang) == "string" and lang:sub(1, 2):lower() == "ar"
end

local function _(str)
    if isArabicUI() and TRANSLATIONS_AR[str] then
        return TRANSLATIONS_AR[str]
    end
    return gettext(str)
end

local Notification
do
    local ok, mod = pcall(require, "ui/widget/notification")
    Notification = ok and mod or nil
end

local function showToast(text, timeout)
    if Notification then
        local ok = pcall(function()
            UIManager:show(Notification:new{ text = text, timeout = timeout or 2 })
        end)
        if ok then return end
    end
    pcall(function()
        UIManager:show(InfoMessage:new{ text = text, timeout = timeout or 2 })
    end)
end

local function copyFile(src, dst)
    local inf = io.open(src, "rb")
    if not inf then return false end
    local outf = io.open(dst, "wb")
    if not outf then 
        inf:close() 
        return false 
    end
    local chunk_size = 4096
    while true do
        local block = inf:read(chunk_size)
        if not block then break end
        outf:write(block)
    end
    inf:close()
    outf:close()
    return true
end

local ArabicEnhancement = WidgetContainer:extend{
    name = "arabicenhancement",
    is_doc_only = false,
}

local ARABIC_RANGES = {
    { 0x0600, 0x06FF }, { 0x0750, 0x077F }, { 0x08A0, 0x08FF },
    { 0xFB50, 0xFDFF }, { 0xFE70, 0xFEFF },
}

local function isArabicCodepoint(cp)
    for idx, range in ipairs(ARABIC_RANGES) do
        if cp >= range[1] and cp <= range[2] then return true end
    end
    return false
end

local function isArabicString(str)
    if type(str) ~= "string" or str == "" then return false end

    if utf8 and utf8.codepoint then
        local found = false
        pcall(function()
            for idx, cp in utf8.codes(str) do
                if isArabicCodepoint(cp) then
                    found = true
                    error("found", 0)
                end
            end
        end)
        return found
    end

    local len = #str
    local i = 1
    while i <= len do
        local b1 = string.byte(str, i)
        local cp, nbytes
        if b1 < 0x80 then cp, nbytes = b1, 1
        elseif b1 >= 0xC0 and b1 < 0xE0 and (i + 1) <= len then
            cp = ((b1 - 0xC0) * 0x40) + (string.byte(str, i + 1) - 0x80)
            nbytes = 2
        elseif b1 >= 0xE0 and b1 < 0xF0 and (i + 2) <= len then
            cp = ((b1 - 0xE0) * 0x1000) + ((string.byte(str, i + 1) - 0x80) * 0x40) + (string.byte(str, i + 2) - 0x80)
            nbytes = 3
        else cp, nbytes = 0, 1 end

        if isArabicCodepoint(cp) then return true end
        i = i + nbytes
    end
    return false
end

local function stripTashkeel(str)
    if type(str) ~= "string" or str == "" then return str end
    return str:gsub("\217[\139-\146\176]", ""):gsub("\216\160", "")
end

local ARABIC_VARIANT_CODES = {
    ar = true, arb = true, arz = true, acm = true, acq = true,
    acw = true, acx = true, acy = true, adf = true, aeb = true,
    aec = true, afb = true, apc = true, apd = true, arq = true,
    ars = true, ary = true, ayh = true, ayl = true,
    ayn = true, ayp = true, shu = true, ssh = true,
}

local function isArabicLangCode(lang)
    if type(lang) ~= "string" or lang == "" then return false end
    lang = lang:lower()
    local code = lang:match("^([%a]+)")
    if code and ARABIC_VARIANT_CODES[code] then return true end
    if lang:find("arabic", 1, true) then return true end
    return false
end

local function isPdfDocument(doc)
    if not doc then return false end
    local file = doc.file
    if type(file) == "string" and file:lower():match("%.pdf$") then
        return true
    end
    return false
end

local function setGlobalKoreaderFont(face)
    if G_reader_settings then
        pcall(function()
            G_reader_settings:saveSetting("font_face", face)
            if G_reader_settings.flush then G_reader_settings:flush() end
        end)
    end
    pcall(function()
        local r_settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/settings.reader.lua")
        if r_settings then
            r_settings:saveSetting("font_face", face)
            r_settings:flush()
        end
    end)
end

local function patchReaderDictionary()
    local ok, ReaderDictionary = pcall(require, "apps/reader/modules/readerdictionary")
    if not ok or not ReaderDictionary or ReaderDictionary._ae_patched then return end
    ReaderDictionary._ae_patched = true

    local orig_lookupWord = ReaderDictionary.lookupWord
    if orig_lookupWord then
        ReaderDictionary.lookupWord = function(self, word, ...)
            if type(word) == "string" and isArabicString(word) then
                local clean = stripTashkeel(word)
                clean = clean:gsub("^[%p%s]+", ""):gsub("[%p%s]+$", "")
                return orig_lookupWord(self, clean, ...)
            end
            return orig_lookupWord(self, word, ...)
        end
    end
end

local function patchReaderHighlight()
    local ok, ReaderHighlight = pcall(require, "apps/reader/modules/readerhighlight")
    if not ok or not ReaderHighlight or ReaderHighlight._ae_patched then return end
    ReaderHighlight._ae_patched = true

    local orig_addBookmark = ReaderHighlight.addBookmark
    if orig_addBookmark then
        ReaderHighlight.addBookmark = function(self, bookmark, ...)
            if bookmark and type(bookmark.text) == "string" and isArabicString(bookmark.text) then
                if not bookmark.text:find("^\226\128\143") then
                    bookmark.text = "\226\128\143" .. bookmark.text
                end
            end
            return orig_addBookmark(self, bookmark, ...)
        end
    end
end

function ArabicEnhancement:provisionBundledFonts()
    local data_dir = DataStorage:getDataDir()
    local assets_dir = data_dir .. "/plugins/arabicenhancement.koplugin/assets"
    local target_dir = data_dir .. "/fonts"

    if lfs.attributes(assets_dir, "mode") ~= "directory" then return end
    if lfs.attributes(target_dir, "mode") ~= "directory" then
        pcall(function() lfs.mkdir(target_dir) end)
    end

    local copied_any = false
    local function scanAndCopy(dir)
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local path = dir .. "/" .. file
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    scanAndCopy(path)
                elseif mode == "file" then
                    local lower_file = file:lower()
                    if lower_file:match("%.ttf$") or lower_file:match("%.otf$") then
                        local target_path = target_dir .. "/" .. file
                        if not lfs.attributes(target_path) then
                            if copyFile(path, target_path) then
                                copied_any = true
                            end
                        end
                    end
                end
            end
        end
    end

    pcall(function() scanAndCopy(assets_dir) end)

    if copied_any then
        local ok_fl, FontList = pcall(require, "fontlist")
        if ok_fl and FontList and FontList.rebuildFontList then
            pcall(function() FontList:rebuildFontList() end)
        end
    end
end

function ArabicEnhancement:setReadingDirection(is_rtl)
    local ui = self.ui
    if not ui or not ui.doc_settings then return end

    ui.doc_settings:saveSetting("inverse_reading_order", is_rtl and true or false)

    local page_turn_module = ui.rolling or ui.paging
    if page_turn_module then
        page_turn_module.inverse_reading_order = is_rtl and true or false
        if page_turn_module.setupTapTouchZones then
            pcall(function() page_turn_module:setupTapTouchZones() end)
        end
    end

    if ui.view then
        ui.view.inverse_reading_order = is_rtl and true or false
        if ui.view.dialog then
            pcall(function() UIManager:setDirty(ui.view.dialog, "ui") end)
        end
    end
end

function ArabicEnhancement:applyArabicSettings()
    local ui = self.ui
    if not ui or not ui.doc_settings then return end

    self:setReadingDirection(true)

    local is_pdf = isPdfDocument(ui.document)
    local applied_font = nil
    local is_crengine = ui.rolling ~= nil

    if not is_pdf and is_crengine then
        if self.settings:isTrue("auto_align_right") then
            ui.doc_settings:saveSetting("text_align", "right")
        end

        if self.settings:isTrue("auto_disable_hyphenation") then
            ui.doc_settings:saveSetting("auto_hyphenation", false)
            ui.doc_settings:saveSetting("hyph_force_algorithmic", false)
        end

        if self.settings:isTrue("auto_line_height") then
            ui.doc_settings:saveSetting("line_space_percent", 130)
        end

        local target_font = self.settings:readSetting("global_fallback_font")
        if not target_font or target_font == "" then
            target_font = "Scheherazade New"
        end
        applied_font = target_font
        ui.doc_settings:saveSetting("font_face", target_font)
        if ui.font and ui.font.onSetFont then
            pcall(function() ui.font:onSetFont(target_font) end)
        elseif ui.view and ui.view.setFontFace then
            pcall(function() ui.view:setFontFace(target_font) end)
        end
    end

    if ui.doc_settings.flush then
        pcall(function() ui.doc_settings:flush() end)
    end

    local msg
    if is_pdf then
        msg = _("Arabic book detected — Arabic reading style applied (RTL)")
    else
        msg = _("Arabic book detected — Arabic reading style applied")
        if applied_font then
            msg = msg .. " (" .. applied_font .. ")"
        end
    end
    showToast(msg, 2)
end

function ArabicEnhancement:applyManualArabicStyle()
    local ui = self.ui
    if not ui or not ui.doc_settings or not ui.document then
        showToast(_("No document open"), 2)
        return
    end

    self:setReadingDirection(true)

    local is_pdf = isPdfDocument(ui.document)
    if is_pdf then
        if ui.doc_settings.flush then
            pcall(function() ui.doc_settings:flush() end)
        end
        showToast(_("Arabic style applied (PDF: RTL page-turning only)"), 2)
        return true
    end

    local applied_font = nil
    local is_crengine = ui.rolling ~= nil

    if is_crengine then
        if self.settings:isTrue("auto_align_right") then
            ui.doc_settings:saveSetting("text_align", "right")
        end

        if self.settings:isTrue("auto_disable_hyphenation") then
            ui.doc_settings:saveSetting("auto_hyphenation", false)
            ui.doc_settings:saveSetting("hyph_force_algorithmic", false)
        end

        if self.settings:isTrue("auto_line_height") then
            ui.doc_settings:saveSetting("line_space_percent", 130)
        end

        local target_font = self.settings:readSetting("global_fallback_font")
        if not target_font or target_font == "" then
            target_font = "Scheherazade New"
        end
        applied_font = target_font
        ui.doc_settings:saveSetting("font_face", target_font)
        if ui.font and ui.font.onSetFont then
            pcall(function() ui.font:onSetFont(target_font) end)
        elseif ui.view and ui.view.setFontFace then
            pcall(function() ui.view:setFontFace(target_font) end)
        end
    end

    if ui.doc_settings.flush then
        pcall(function() ui.doc_settings:flush() end)
    end

    local msg = _("Arabic style applied — RTL enabled")
    if applied_font then
        msg = msg .. " (" .. applied_font .. ")"
    end
    showToast(msg, 2)
    return true
end

function ArabicEnhancement:toggleReversePageOrder()
    local ui = self.ui
    if not ui or not ui.document or not ui.doc_settings then
        showToast(_("No document open"), 2)
        return
    end

    local total = nil
    pcall(function() total = ui.document:getPageCount() end)
    if not total or total <= 1 then
        showToast(_("Not available for this document type"), 2)
        return
    end

    local is_reversed = ui.doc_settings:has("page_map")
    if is_reversed then
        ui.doc_settings:delSetting("page_map")
        if ui.doc_settings.flush then ui.doc_settings:flush() end
        if ui.paging and ui.paging.onGotoPage then
            local cur = ui.paging.current_page or 1
            pcall(function() ui.paging:onGotoPage(total - cur + 1) end)
        end
        showToast(_("Original page order restored"), 2)
    else
        local map = {}
        for p = 1, total do
            map[p] = total - p + 1
        end
        ui.doc_settings:saveSetting("page_map", map)
        if ui.doc_settings.flush then ui.doc_settings:flush() end
        if ui.paging and ui.paging.onGotoPage then
            local cur = ui.paging.current_page or 1
            pcall(function() ui.paging:onGotoPage(total - cur + 1) end)
        end
        showToast(_("Page order reversed"), 2)
    end

    if ui.view and ui.view.dialog then
        pcall(function() UIManager:setDirty(ui.view.dialog, "ui") end)
    end
end

function ArabicEnhancement:isArabicBook()
    local doc = self.ui and self.ui.document
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

    local toc = nil
    local ok_toc = pcall(function() toc = doc:getToc() end)
    if not ok_toc then
        ok_toc = pcall(function() toc = doc:getTOC() end)
    end

    if ok_toc and type(toc) == "table" then
        local count = 0
        local function scanToc(items)
            for idx, item in ipairs(items) do
                count = count + 1
                if count > 20 then return false end
                if item.title and isArabicString(item.title) then
                    return true
                end
                if item.subitems and scanToc(item.subitems) then
                    return true
                end
            end
            return false
        end
        if scanToc(toc) then return true end
    end

    local file_path = doc.file or (self.ui and self.ui.document and self.ui.document.file)
    if type(file_path) == "string" and isArabicString(file_path) then
        return true
    end

    return false
end

function ArabicEnhancement:onToggleArabicRTL()
    local ui = self.ui
    if not ui or not ui.doc_settings then return end

    local current = ui.doc_settings:readSetting("inverse_reading_order")
    local new_value = not (current == true)

    self:setReadingDirection(new_value)

    if ui.rolling then
        if new_value then
            ui.doc_settings:saveSetting("text_align", "right")
        else
            ui.doc_settings:delSetting("text_align")
        end
    end

    if ui.doc_settings.flush then
        pcall(function() ui.doc_settings:flush() end)
    end

    showToast(new_value and _("Right-to-left enabled") or _("Left-to-right enabled"), 2)
    return true
end

function ArabicEnhancement:onApplyManualArabicStyle()
    return self:applyManualArabicStyle()
end

function ArabicEnhancement:runAutoDetect()
    if self._auto_detect_ran then return end
    self._auto_detect_ran = true

    if not self.ui or not self.ui.doc_settings then return end
    if not self.settings:isTrue("auto_detect") then return end
    if self.ui.doc_settings:has("inverse_reading_order") then return end

    local ok, is_arabic = pcall(function() return self:isArabicBook() end)
    if ok and is_arabic then
        self:applyArabicSettings()
    end
end

function ArabicEnhancement:onReaderReady()
    UIManager:nextTick(function()
        self:runAutoDetect()
    end)
end

function ArabicEnhancement:init()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/arabicenhancement.lua")

    pcall(function() self:provisionBundledFonts() end)

    if not self.settings:has("auto_detect") then 
        self.settings:saveSetting("auto_detect", true) 
    end
    if not self.settings:has("auto_align_right") then 
        self.settings:saveSetting("auto_align_right", true) 
    end
    if not self.settings:has("auto_disable_hyphenation") then 
        self.settings:saveSetting("auto_disable_hyphenation", true) 
    end
    if not self.settings:has("auto_line_height") then 
        self.settings:saveSetting("auto_line_height", true) 
    end
    if not self.settings:has("enhanced_dictionary") then 
        self.settings:saveSetting("enhanced_dictionary", true) 
    end
    if not self.settings:has("clean_clippings") then 
        self.settings:saveSetting("clean_clippings", true) 
    end
    if not self.settings:has("global_fallback_font") then 
        self.settings:saveSetting("global_fallback_font", "Scheherazade New") 
    end
    self.settings:flush()

    if self.settings:isTrue("enhanced_dictionary") then
        pcall(patchReaderDictionary)
    end
    if self.settings:isTrue("clean_clippings") then
        pcall(patchReaderHighlight)
    end

    pcall(function() self:onDispatcherRegisterActions() end)

    if self.ui and self.ui.menu then
        pcall(function() self.ui.menu:registerToMainMenu(self) end)
    end

    if self.ui and self.ui.registerPostInitCallback then
        pcall(function()
            self.ui:registerPostInitCallback(function()
                UIManager:nextTick(function() self:runAutoDetect() end)
            end)
        end)
    end
end

function ArabicEnhancement:onDispatcherRegisterActions()
    Dispatcher:registerAction("arabicenhancement_apply_style", {
        category = "none",
        event = "ApplyManualArabicStyle",
        title = _("Arabic Enhancement: apply Arabic style to current book"),
        reader = true,
    })
    Dispatcher:registerAction("arabicenhancement_toggle_rtl", {
        category = "none",
        event = "ToggleArabicRTL",
        title = _("Arabic Enhancement: toggle RTL for this book"),
        reader = true,
    })
end

function ArabicEnhancement:getPluginMenu()
    local current_is_pdf = self.ui and self.ui.document and isPdfDocument(self.ui.document)

    return {
        text = _("Arabic Enhancement"),
        sorting_hint = "typeset",
        sub_item_table = {
            {
                text = _("Auto-detect Arabic books"),
                checked_func = function() return self.settings:isTrue("auto_detect") end,
                callback = function()
                    self.settings:saveSetting("auto_detect", not self.settings:isTrue("auto_detect"))
                    self.settings:flush()
                end,
                help_text = _("Auto-detect and switch to RTL for Arabic books"),
            },
            {
                text = _("Apply Arabic style to this book"),
                enabled_func = function()
                    return self.ui ~= nil and self.ui.document ~= nil
                end,
                callback = function()
                    self:applyManualArabicStyle()
                end,
                help_text = _("Manually sets RTL (Fonts/Align ignored for PDF)"),
                separator = true,
            },
            {
                text = _("Toggle right-to-left for this book"),
                enabled_func = function() 
                    return self.ui ~= nil and self.ui.document ~= nil 
                end,
                keep_menu_open = true,
                callback = function() self:onToggleArabicRTL() end,
            },
            {
                text = _("Reverse page order for this book"),
                enabled_func = function()
                    return self.ui ~= nil and self.ui.document ~= nil
                end,
                callback = function()
                    self:toggleReversePageOrder()
                end,
                separator = true,
            },
            {
                text = _("Auto-align text to the right"),
                enabled_func = function()
                    return not current_is_pdf
                end,
                checked_func = function() return self.settings:isTrue("auto_align_right") end,
                callback = function()
                    self.settings:saveSetting("auto_align_right", not self.settings:isTrue("auto_align_right"))
                    self.settings:flush()
                end,
                help_text = current_is_pdf and _("Not available for PDF files") or nil,
            },
            {
                text = _("Auto-disable hyphenation"),
                enabled_func = function()
                    return not current_is_pdf
                end,
                checked_func = function() return self.settings:isTrue("auto_disable_hyphenation") end,
                callback = function()
                    self.settings:saveSetting("auto_disable_hyphenation", not self.settings:isTrue("auto_disable_hyphenation"))
                    self.settings:flush()
                end,
                help_text = current_is_pdf and _("Not available for PDF files") or nil,
            },
            {
                text = _("Auto line-height (130%)"),
                enabled_func = function()
                    return not current_is_pdf
                end,
                checked_func = function() return self.settings:isTrue("auto_line_height") end,
                callback = function()
                    self.settings:saveSetting("auto_line_height", not self.settings:isTrue("auto_line_height"))
                    self.settings:flush()
                end,
                help_text = current_is_pdf and _("Not available for PDF files") or nil,
                separator = true,
            },
            {
                text = _("Enhanced dictionary lookup"),
                checked_func = function() return self.settings:isTrue("enhanced_dictionary") end,
                callback = function()
                    local nv = not self.settings:isTrue("enhanced_dictionary")
                    self.settings:saveSetting("enhanced_dictionary", nv)
                    self.settings:flush()
                    if nv then pcall(patchReaderDictionary) end
                end,
            },
            {
                text = _("Clean Arabic clippings (RLM)"),
                checked_func = function() return self.settings:isTrue("clean_clippings") end,
                callback = function()
                    local nv = not self.settings:isTrue("clean_clippings")
                    self.settings:saveSetting("clean_clippings", nv)
                    self.settings:flush()
                    if nv then pcall(patchReaderHighlight) end
                end,
                separator = true,
            },
            {
                text = _("Default fallback font"),
                enabled_func = function()
                    return not current_is_pdf
                end,
                sub_item_table_func = function()
                    local items = {}
                    local current = self.settings:readSetting("global_fallback_font")

                    for idx, f in ipairs(BUNDLED_FONTS) do
                        table.insert(items, {
                            text = f.name,
                            checked = (current == f.face),
                            callback = function()
                                self.settings:saveSetting("global_fallback_font", f.face)
                                self.settings:flush()

                                setGlobalKoreaderFont(f.face)

                                if self.ui and self.ui.doc_settings and self.ui.rolling then
                                    self.ui.doc_settings:saveSetting("font_face", f.face)
                                    if self.ui.font and self.ui.font.onSetFont then
                                        pcall(function() self.ui.font:onSetFont(f.face) end)
                                    elseif self.ui.view and self.ui.view.setFontFace then
                                        pcall(function() self.ui.view:setFontFace(f.face) end)
                                    end
                                    if self.ui.doc_settings.flush then
                                        pcall(function() self.ui.doc_settings:flush() end)
                                    end
                                end

                                UIManager:nextTick(function()
                                    showToast(_("Font set system-wide to: ") .. f.name, 2)
                                end)
                            end,
                        })
                    end
                    return items
                end,
                help_text = current_is_pdf and _("Not available for PDF files") or _("Select fallback font from bundled assets"),
            },
        },
    }
end

function ArabicEnhancement:addToMainMenu(menu_items)
    menu_items.arabicenhancement = self:getPluginMenu()
end

function ArabicEnhancement:addToReaderMenu(menu_items)
    menu_items.arabicenhancement = self:getPluginMenu()
end

return ArabicEnhancement

