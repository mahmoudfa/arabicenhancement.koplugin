# Arabic Enhancement — `arabicenhancement.koplugin`

[

![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)

](LICENSE)
[

![KOReader Plugin](https://img.shields.io/badge/KOReader-Plugin-green.svg)

](https://github.com/koreader/koreader)

A [KOReader](https://github.com/koreader/koreader) plugin for E-ink devices that detects Arabic-language books and automatically switches page-turn direction to right-to-left — without ever overwriting a setting you've already configured yourself.

## What it does

On first open of a book, the plugin checks once whether it's Arabic:

1. **Metadata** — language code (`ar` and other ISO 639 Arabic variants), plus title, author, keywords, and description scanned for Arabic Unicode ranges (U+0600–U+06FF, U+0750–U+077F, U+08A0–U+08FF, U+FB50–U+FDFF, U+FE70–U+FEFF).
2. **Table of contents** — first ~20 entries (recursive into sub-items), scanned the same way. Works across both the CRE (EPUB/FB2/MOBI/AZW3) and MuPDF (PDF/DjVu) engines.

If Arabic is detected:

- **Right-to-left page turning** is enabled and applied to the already-open reader immediately — no reload required.
- **Right text alignment** is applied on reflowable books (EPUB/FB2/MOBI/AZW3) — *experimental, see note below*.
- A **fallback font** (your choice, from fonts already on your device) is applied to reflowable books that don't already have a font of their own set.
- A brief toast confirms the change.

Supported formats: **EPUB, PDF, FB2, MOBI, AZW3, DjVu**.

> **Note on the font feature:** this plugin does **not** bundle or install new font files — KOReader has no supported way for a plugin to do that (see [koreader/koreader#13271](https://github.com/koreader/koreader/issues/13271), open at time of writing). Instead, it lets you pick a fallback font from whatever KOReader already knows about on your device. If you want a specific Arabic typeface (Amiri, Noto Naskh Arabic, Scheherazade New, etc.), download it separately and drop it into your KOReader **fonts** folder first — it will then appear in this plugin's font list after a restart.

> **Note on auto-alignment:** the right-alignment feature relies on an internal API this plugin hasn't been able to fully verify against KOReader's typesetting module. It's wrapped safely (it will never crash or break your book), but it may currently have no visible effect on some KOReader versions. RTL page-turning is unaffected either way and works reliably.

## It never overwrites your own choices

- A book that already has a reading-direction setting — from you, a directory default, or another plugin — before this plugin ever runs on it is left completely alone.
- A book with its own font already set is never overridden.
- Non-Arabic books are left untouched entirely.

## Menu

**Tools → Arabic Enhancement**:

| Item | Action |
|---|---|
| Auto-detect Arabic books | Global on/off toggle for automatic detection (enabled by default). |
| Auto-align text to the right | Global on/off toggle for the right-alignment feature (enabled by default). |
| Toggle right-to-left for this book | Manually flips reading direction for the current book, applied immediately. |
| Fallback font for Arabic books | Submenu listing fonts already available on your device to use as the default for reflowable Arabic books. |

A dispatcher action, `arabicenhancement_toggle_rtl`, is also registered, so **Toggle right-to-left for this book** can be bound to a gesture or hardware button via **Settings → Taps and gestures → Gesture manager**.

## Installation

1. Go to [Releases](https://github.com/mahmoudfa/arabicenhancement.koplugin/releases) and download either:
   - the **`arabicenhancement.koplugin.zip`** asset attached to the release (extracts to the correct folder name directly), **or**
   - GitHub's auto-generated **"Source code (zip)"** link.
2. Extract the archive.
   - If you used `arabicenhancement.koplugin.zip`, you already have a folder named exactly `arabicenhancement.koplugin` — skip to step 4.
   - If you used **"Source code (zip)"**, the extracted folder will be named `arabicenhancement.koplugin-<version>`. **Rename it** to exactly `arabicenhancement.koplugin` — KOReader only recognizes plugin folders whose name ends in `.koplugin` with no extra suffix.
3. Confirm the folder is now named exactly `arabicenhancement.koplugin`.
4. Copy that folder into your KOReader plugins directory:

   | Device | Path |
   |---|---|
   | Kindle | `/mnt/us/koreader/plugins/` |
   | Kobo | `.adds/koreader/plugins/` |
   | PocketBook | `system/koreader/plugins/` |
   | Android | `/sdcard/koreader/plugins/` |
   | Linux / macOS | `~/.config/koreader/plugins/` |

5. Restart KOReader.
6. If the plugin doesn't appear under **Tools**, check **Tools → More tools → Plugin management** (on KOReader versions that have it) and make sure it's enabled.
7. Open an Arabic book — a short toast confirms the switch to RTL.

## Repository structure

```
arabicenhancement.koplugin/
├── _meta.lua   # plugin manifest read by KOReader's plugin loader
├── main.lua    # detection logic, RTL/alignment/font application, menu integration
├── LICENSE     # AGPL-3.0
└── README.md
```

## Compatibility

- Requires a KOReader build exposing `ui.doc_settings`, `setupTapTouchZones()` on `ReaderRolling`/`ReaderPaging`, and `fontlist`'s `getFontList()` — present in current releases.
- Written defensively throughout (`pcall` + nil checks) so that an unavailable or renamed internal API degrades to "feature has no effect" rather than crashing the reader.
- Arabic-text detection works on both LuaJIT (KOReader's normal interpreter, no built-in `utf8` library) and Lua 5.3+ builds.

## License

AGPL-3.0, matching KOReader itself.