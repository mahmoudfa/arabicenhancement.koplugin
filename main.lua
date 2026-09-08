--[[--
@module koplugin.arabicenhancement

Arabic Enhancement
===================

Detects Arabic-language books (EPUB, FB2, MOBI/AZW3 via the CRE "rolling"
engine, or PDF/DjVu via the "paging" engine) and automatically:

  * switches page-turn direction to right-to-left (`inverse_reading_order`),
  * right-aligns text on reflowable (CRE) documents,
  * applies a user-chosen fallback font to reflowable documents that don't
    already have one set,

without ever overwriting a setting the user (or another plugin, or a
directory default) has already configured for that book.

Design notes / known KOReader constraints this code deliberately respects:

  * There is no supported KOReader API for a plugin to auto-register fonts
    bundled inside its own plugin folder (this is an open upstream feature
    request, koreader/koreader#13271, unresolved as of writing). Rather than
    depend on a non-existent API, the font feature here lets the user pick
    from fonts KOReader *already* knows about (via `fontlist`), which is
    fully supported and requires no file copying or restart.
  * `setupTapTouchZones()` lives on the `ReaderRolling` / `ReaderPaging`
    module instances (`ui.rolling` / `ui.paging`), not on `ReaderUI` (`ui`)
    itself -- calling it on the wrong object silently no-ops.
  * `inverse_reading_order` is read by KOReader's own core code as a
    strict boolean; it must be saved as `true`/`false`, not `1`/`0`.
  * Menu registration must happen in `init()`, which runs once per plugin
    instantiation (both the FileManager instance and the ReaderUI instance
    when `is_doc_only = false`). Registering only inside `onReaderReady`
    means the FileManager instance -- where that event never fires --
    never gets a menu entry at all.

License: AGPL-3.0 (matches KOReader itself).
--]]--

local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local FontList = require("fontlist")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

-- Lightweight, non-intrusive toast. `ui/widget/notification` is a newer
-- widget that isn't present on every KOReader release, so we try it first
-- and transparently fall back to the universally-available InfoMessage.
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
    UIManager:show(InfoMessage:new{ text = text, timeout = timeout or 2 })
end

-- ---------------------------------------------------------------------
-- Plugin definition
-- ---------------------------------------------------------------------

local ArabicEnhancement = WidgetContainer:extend{
    name = "arabicenhancement",
    -- Instantiated in both the FileManager and the Reader, so the menu
    -- entry (global toggles, font choice) is reachable from the file
    -- browser too, not only while a book happens to be open.
    is_doc_only = false,
}

-- ---------------------------------------------------------------------
-- Arabic Unicode ranges
-- ---------------------------------------------------------------------
-- Standard Arabic, Arabic Supplement, Arabic Extended-A, and the two
-- Arabic Presentation Forms blocks (ligatures some producers emit).
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

--- UTF-8-aware Arabic detector. Uses the native `utf8` library where
-- available (Lua 5.3+ builds) and falls back to manual byte decoding on
-- LuaJIT (the interpreter KOReader normally ships), which has no `utf8`
-- library at all.
local function isArabicString(str)
    if type(str) ~= "string" or str == "" then
        return false
    end

    if utf8 and utf8.codepoint then
        local found = false
        pcall(function()
            for _, cp in utf8.codes(str) do
                if isArabicCodepoint(cp) then
                    found = true
                    error("found", 0) -- short-circuit the loop
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

-- ---------------------------------------------------------------------
-- Language-code detection
-- ---------------------------------------------------------------------
-- Bare primary subtag ("ar") plus the ISO 639-3 codes for the major
-- Arabic macrolanguage varieties publishers sometimes use instead.
local ARABIC_VARIANT_CODES = {
    ar = true, ara = true, arb = true, arz = true, acm = true, acq = true,
    acw = true, acx = true, acy = true, adf = true, aeb = true,
    aec = true, afb = true, apc = true, apd = true, arq = true,
    ars = true, ary = true, ayh = true, ayl = true,
    ayn = true, ayp = true, shu = true, ssh = true,
}

local function isArabicLangCode(lang)
    if type(lang) ~= "string" or lang == "" then
        return false
    end
    lang = lang:lower()
    local code = lang:match("^([%a]+)")
    if code and ARABIC_VARIANT_CODES[code] then
        return true
    end
    if lang:find("arabic", 1, true) then
        return true
    end
    return false
end

-- ---------------------------------------------------------------------
-- Font enumeration
-- ---------------------------------------------------------------------
-- Lists fonts KOReader already knows about on this device (bundled +
-- anything the user has already dropped into their own fonts folder).
-- We do NOT attempt to bundle or install new font files ourselves --
-- see the module docstring for why.
local function getAvailableFonts()
    local fonts = {}
    local ok, face_list = pcall(function()
        return FontList:getFontList()
    end)

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

--- `document:getToc()` is the documented spelling; a couple of forks and
-- older snapshots have used `getTOC()`. Try both defensively so a casing
-- mismatch degrades to "no TOC data" instead of silently doing nothing
-- forever without anyone noticing.
local function getDocumentToc(document)
    local ok, toc = pcall(function() return document:getToc() end)
    if ok and type(toc) == "table" then
        return toc
    end
    local ok2, toc2 = pcall(function() return document:getTOC() end)
    if ok2 and type(toc2) == "table" then
        return toc2
    end
    return nil
end

-- ---------------------------------------------------------------------
-- Detection
-- ---------------------------------------------------------------------

function ArabicEnhancement:isArabicBook()
    local doc = self.ui.document
    if not doc then
        return false
    end

    -- 1) Metadata: language code, title, author, keywords, description.
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

    -- 2) Table of contents (first ~20 entries, recursive into subitems).
    local toc = getDocumentToc(doc)
    if toc then
        local count = 0
        local function scanToc(items)
            for _, item in ipairs(items) do
                count = count + 1
                if count > 20 then
                    return false
                end
                if item.title and isArabicString(item.title) then
                    return true
                end
                if item.subitems and scanToc(item.subitems) then
                    return true
                end
            end
            return false
        end
        if scanToc(toc) then
            return true
        end
    end

    return false
end

-- ---------------------------------------------------------------------
-- Applying reading direction / alignment / font
-- ---------------------------------------------------------------------

--- Pushes `inverse_reading_order` into whichever reading-direction module
-- is actually mounted (`ui.rolling` for EPUB/FB2/MOBI/AZW3, `ui.paging`
-- for PDF/DjVu) and refreshes tap zones on THAT module -- not on `ui`
-- itself, which has no such method.
function ArabicEnhancement:setReadingDirection(is_rtl)
    local ui = self.ui
    if not ui or not ui.doc_settings then
        return
    end

    -- KOReader's own core code reads this as a strict boolean.
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

--- First-time application when Arabic is auto-detected: RTL + right
-- alignment + fallback font, but only for facets the book doesn't
-- already have an explicit setting for.
function ArabicEnhancement:applyArabicSettings()
    local ui = self.ui
    if not ui or not ui.doc_settings then
        return
    end

    self:setReadingDirection(true)

    local applied_font = nil
    local is_crengine = ui.rolling ~= nil -- reflowable (EPUB/FB2/MOBI/AZW3)

    if is_crengine then
        -- Right-align paragraphs -- meaningful only for reflowable text;
        -- fixed-page PDFs/DjVu already render their original layout.
        if self.settings:isTrue("auto_align_right") and not ui.doc_settings:has("text_align") then
            ui.doc_settings:saveSetting("text_align", "right")
            if ui.rolling.onSetTextAlign then
                pcall(function() ui.rolling:onSetTextAlign("right") end)
            end
        end

        -- Fallback font, only if the book has no font of its own set.
        if not ui.doc_settings:has("font_face") then
            local preferred = self.settings:readSetting("preferred_font")
            if preferred and preferred ~= "" then
                applied_font = preferred
                ui.doc_settings:saveSetting("font_face", preferred)
                -- Apply live via the sibling ReaderFont module, the same
                -- one KOReader's own font-picker menu calls into.
                if ui.font and ui.font.onSetFont then
                    pcall(function() ui.font:onSetFont(preferred) end)
                end
            end
        end
    end

    if ui.doc_settings.flush then
        pcall(function() ui.doc_settings:flush() end)
    end

    local msg = _("Arabic detected — right-to-left enabled")
    if applied_font then
        msg = msg .. " (" .. applied_font .. ")"
    end
    showToast(msg, 3)
end

-- ---------------------------------------------------------------------
-- Manual toggle (menu item + dispatcher action)
-- ---------------------------------------------------------------------

function ArabicEnhancement:onToggleArabicRTL()
    local ui = self.ui
    if not ui or not ui.doc_settings then
        return
    end

    local current = ui.doc_settings:readSetting("inverse_reading_order")
    local new_value = not (current == true)

    self:setReadingDirection(new_value)

    if ui.rolling then
        if new_value then
            ui.doc_settings:saveSetting("text_align", "right")
            if ui.rolling.onSetTextAlign then
                pcall(function() ui.rolling:onSetTextAlign("right") end)
            end
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

-- ---------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------

--- Runs once per book open. Menu registration does NOT happen here --
-- see `init()` -- this hook only ever fires for the ReaderUI instance,
-- never for the FileManager one.
function ArabicEnhancement:onReaderReady()
    UIManager:nextTick(function()
        if not self.ui or not self.ui.doc_settings then
            return
        end
        if not self.settings:isTrue("auto_detect") then
            return
        end
        -- Never touch a book that already has a reading-direction
        -- setting -- from the user, a directory default, or us on a
        -- previous open.
        if self.ui.doc_settings:has("inverse_reading_order") then
            return
        end

        local ok, is_arabic = pcall(function() return self:isArabicBook() end)
        if ok and is_arabic then
            self:applyArabicSettings()
        end
    end)
end

--- Runs once per instantiation -- both for the FileManager instance and
-- for each ReaderUI instance. Menu and dispatcher registration belong
-- here so they are reachable from both the file browser and the reader.
function ArabicEnhancement:init()
    self.settings = DataStorage:getSettings("arabicenhancement")

    if not self.settings:has("auto_detect") then
        self.settings:saveSetting("auto_detect", true)
    end
    if not self.settings:has("auto_align_right") then
        self.settings:saveSetting("auto_align_right", true)
    end
    if not self.settings:has("preferred_font") then
        local fonts = getAvailableFonts()
        self.settings:saveSetting("preferred_font", fonts[1] and fonts[1].face or "")
    end
    self.settings:flush()

    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

--- Registered once via the dedicated dispatcher lifecycle hook, so the
-- action exists exactly once regardless of how many times `init()` runs
-- across FileManager / Reader instantiations.
function ArabicEnhancement:onDispatcherRegisterActions()
    Dispatcher:registerAction("arabicenhancement_toggle_rtl", {
        category = "none",
        event = "ToggleArabicRTL",
        title = _("Arabic Enhancement: toggle RTL for this book"),
        reader = true,
    })
end

-- ---------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------

function ArabicEnhancement:addToMainMenu(menu_items)
    menu_items.arabicenhancement = {
        text = _("Arabic Enhancement"),
        sorting_hint = "typeset",
        sub_item_table = {
            {
                text = _("Auto-detect Arabic books"),
                checked_func = function()
                    return self.settings:isTrue("auto_detect")
                end,
                callback = function()
                    self.settings:saveSetting("auto_detect", not self.settings:isTrue("auto_detect"))
                    self.settings:flush()
                end,
                help_text = _("When enabled, each newly opened book is checked once for Arabic text and switched to right-to-left automatically. Books with an existing reading-direction setting are never touched."),
            },
            {
                text = _("Auto-align text to the right"),
                checked_func = function()
                    return self.settings:isTrue("auto_align_right")
                end,
                callback = function()
                    self.settings:saveSetting("auto_align_right", not self.settings:isTrue("auto_align_right"))
                    self.settings:flush()
                end,
                separator = true,
            },
            {
                text = _("Toggle right-to-left for this book"),
                enabled_func = function()
                    return self.ui ~= nil and self.ui.document ~= nil
                end,
                keep_menu_open = true,
                callback = function() self:onToggleArabicRTL() end,
                separator = true,
            },
            {
                text = _("Fallback font for Arabic books"),
                sub_item_table = function()
                    local items = {}
                    local current = self.settings:readSetting("preferred_font")
                    for _, f in ipairs(getAvailableFonts()) do
                        table.insert(items, {
                            text = f.text,
                            checked = (current == f.face),
                            callback = function()
                                self.settings:saveSetting("preferred_font", f.face)
                                self.settings:flush()
                                showToast(_("Fallback font set to: ") .. f.text, 2)
                            end,
                        })
                    end
                    return items
                end,
                help_text = _("Used only for reflowable books (EPUB/FB2/MOBI/AZW3) that don't already have a font of their own set. Lists fonts already available on this device."),
            },
        },
    }
end

return ArabicEnhancement
