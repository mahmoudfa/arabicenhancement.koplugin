local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

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

local fullname = isArabicUI() and "تحسينات اللغة العربية" or "Arabic Enhancement"
local description = isArabicUI() 
    and "يكتشف الكتب العربية تلقائياً ويعكس اتجاه تقليب الصفحات لليمين، ويحاذي النص، ويضبط الخط وتباعد الأسطر والفواصل والمعاجم والمقتبسات دون الكتابة فوق إعداداتك المسبقة."
    or "Detects Arabic-language books and automatically switches page-turn direction to right-to-left, adjusts typography, line-height, hyphenation, dictionaries, and clippings without overwriting settings."

return {
    fullname = fullname,
    description = description,
    version = 3,
}

