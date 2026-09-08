local _ = require("gettext")

return {
    name = "arabicenhancement",
    fullname = _("Arabic Enhancement"),
    description = _([[Detects Arabic-language books and automatically switches page-turn direction to right-to-left, right-aligns text, and applies a fallback font — without overwriting settings you've already configured.]]),
    version = 1,
}
