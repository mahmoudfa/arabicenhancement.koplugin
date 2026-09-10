# Arabic Enhancement — `arabicenhancement.koplugin`
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)
[![KOReader Plugin](https://img.shields.io/badge/KOReader-Plugin-green.svg)](https://github.com/koreader/koreader)
[![Version](https://img.shields.io/badge/Version-1.0-orange.svg)]()
A comprehensive typography, reading-direction, and utility plugin for [KOReader](https://github.com/koreader/koreader) on E-ink devices. It automatically detects Arabic books, applies optimal Arabic typesetting defaults, provisions bundled fonts, and streamlines reading workflows across EPUBs and PDFs without overwriting your manual configurations.
---

[![Download Latest Release](https://img.shields.io/github/v/release/mahmoudfa/arabicenhancement.koplugin?label=Download%20Plugin&color=green)](https://github.com/mahmoudfa/arabicenhancement.koplugin/releases/latest/download/arabicenhancement.koplugin.zip)

## Key Features
### 1. Smart Arabic Detection & Instant RTL
On opening any document, the plugin scans:
* **Metadata:** Language codes (`ar`, `arb`, `arz`, etc.) and Arabic Unicode ranges across title, author, keywords, and description.
* **Table of Contents (TOC):** First 20 entries for Arabic characters.
* **File Path:** The file name itself as a reliable fallback for files with missing or corrupted metadata.
Once an Arabic book is detected:
* **Right-to-left page turning** is applied immediately.
* **Screen touch zones** invert dynamically to match RTL reading order without reloading or reopening the book.
* A clean 2-second toast confirms activation.
### 2. Reflowable Typography Tweaks (EPUB / MOBI / FB2)
* **Default Typeface (Scheherazade New):** Books without an explicit font face automatically adopt **Scheherazade New** upon detection.
* **Auto Line-Height Scaling (130%):** Arabic scripts feature tall ascenders, deep descenders, and vertical diacritics. Setting line-height to 130% prevents overlapping accents between lines.
* **Disable Algorithmic Hyphenation:** Disables Latin word-break algorithms for Arabic books, stopping erratic hyphens from splitting Arabic words.
* **Auto Right-Alignment:** Right-aligns reflowable paragraphs while preserving document layout.
### 3. Bundled Fonts & System-Wide Synchronization
* **Ships with three high-legibility Arabic font families (Regular & Bold):**
  * **Scheherazade New** (Default)
  * **Amiri**
  * **Cairo**
* **Zero-Config Installation:** Fonts located in `assets/` are automatically copied to KOReader's `fonts/` directory on boot, and the internal font cache is rebuilt dynamically without needing a device restart.
* **System-Wide Preference:** Choosing a font from the plugin menu updates the open book and saves the setting globally across KOReader (`settings.reader.lua`).
### 4. PDF & Fixed-Layout Engine Support
* **Safe PDF Mode:** For fixed-layout PDF and DjVu files, the plugin enables RTL page-turning while automatically disabling and greying out incompatible options (fonts, line spacing, text alignment) to prevent engine conflicts.
* **Reverse Page Order (Scanned Book Fix):** Heritage books or scanned documents digitized backwards can have their page order flipped end-to-end (from the last page to the first) via dynamic page mapping without altering the physical file.
### 5. Research & Reading Tools
* **Enhanced Dictionary Lookup (Tashkeel Stripping):** Automatically strips vowel marks (tashkeel, tanween, shaddah) and surrounding punctuation from highlighted words before querying StarDict dictionaries, significantly improving hit rates.
* **Clean Arabic Clippings (RLM Formatting):** Automatically prepends the invisible Unicode Right-to-Left Mark (`\u{200F}`) to highlights and notes, preventing parentheses and punctuation marks from flipping when exporting to Obsidian, Notion, or text editors.
### 6. Dynamic Bilingual UI
The entire interface, menu options, help descriptions, and status toasts automatically switch between **Arabic** and **English** based on KOReader's global UI language setting.
---
## Menu Structure
Accessible under **Tools -> Arabic Enhancement** (or **الأدوات -> تحسينات اللغة العربية**):

| Option | Description |
| :--- | :--- |
| **Auto-detect Arabic books** | Global toggle for automatic Arabic detection on open. |
| **Apply Arabic style to this book** | Manually applies RTL and Arabic typography rules to the active book. |
| **Toggle right-to-left for this book** | Inverts page-turning direction for the active document. |
| **Reverse page order for this book** | Reverses page sequence for backwards-scanned books. |
| **Auto-align text to the right** | Auto-aligns text to the right (Disabled for PDF). |
| **Auto-disable hyphenation** | Disables word-breaking algorithms (Disabled for PDF). |
| **Auto line-height (130%)** | Expands line height to accommodate Arabic diacritics (Disabled for PDF). |
| **Enhanced dictionary lookup** | Strips diacritics when querying dictionaries. |
| **Clean Arabic clippings (RLM)** | Injects RLM markers to preserve punctuation in exported notes. |
| **Default fallback font** | Select between Scheherazade New, Amiri, and Cairo. Applies system-wide. |

---
## Gesture Manager (Dispatcher Actions)
Two actions can be mapped to physical buttons or swipe gestures via **Settings -> Taps and gestures -> Gesture manager**:
* `arabicenhancement_apply_style`: Apply Arabic reading style to the current book.
* `arabicenhancement_toggle_rtl`: Toggle RTL reading direction for the current book.
---
## Installation
1. Download the latest release from the [Releases](https://github.com/mahmoudfa/arabicenhancement.koplugin/releases) page.
2. Ensure the extracted folder is named exactly: `arabicenhancement.koplugin`.
3. Copy `arabicenhancement.koplugin` into your device's KOReader plugins directory:

| Device | Path |
| :--- | :--- |
| **Kindle** | `/mnt/us/koreader/plugins/` |
| **Kobo** | `.adds/koreader/plugins/` |
| **PocketBook** | `system/koreader/plugins/` |
| **Android** | `/sdcard/koreader/plugins/` |
| **Desktop (Linux / macOS)** | `~/.config/koreader/plugins/` |

4. Restart KOReader.
5. Open an Arabic book — a confirmation toast will indicate the Arabic reading style has been applied.

### Directory Structure

```
arabicenhancement.koplugin/
├── _meta.lua
├── main.lua
├── LICENSE
├── README.md
└── assets/
    ├── Amiri/
    │   ├── Amiri-Regular.ttf
    │   └── Amiri-Bold.ttf
    ├── Cairo/
    │   ├── Cairo-Regular.ttf
    │   └── Cairo-Bold.ttf
    └── Scheherazade_New/
        ├── ScheherazadeNew-Regular.ttf
        └── ScheherazadeNew-Bold.ttf
```

---
## Compatibility & License
Fully compatible with all supported KOReader hardware (Kindle, Kobo, PocketBook, Android, and Desktop platforms).
Compatible with both LuaJIT and Lua 5.3+ runtimes.
Built defensively using protected calls (pcall) to maintain compatibility with future KOReader API updates.
License: AGPL-3.0 (matching KOReader core).  
   