# Arabic Enhancement — `arabicenhancement.koplugin`
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)
[![KOReader Plugin](https://img.shields.io/badge/KOReader-Plugin-green.svg)](https://github.com/koreader/koreader)
[![Version](https://img.shields.io/badge/Version-3.0-orange.svg)]()
A comprehensive typography, reading-direction, and utility plugin for [KOReader](https://github.com/koreader/koreader) on E-ink devices. It automatically detects Arabic books, applies optimal Arabic typesetting defaults, provisions bundled fonts, and streamlines reading workflows across EPUBs and PDFs without overwriting your manual configurations[span_0](start_span)[span_0](end_span)[span_1](start_span)[span_1](end_span).
---
## Key Features
### 1. Smart Arabic Detection & RTL Switching
On opening a document, the plugin scans:
* **Metadata:** Language codes (`ar`, `arb`, `arz`, etc.) and Unicode Arabic ranges in Title, Author, Keywords, and Description[span_2](start_span)[span_2](end_span)[span_3](start_span)[span_3](end_span).
* **Table of Contents (TOC):** First ~20 entries for Arabic characters[span_4](start_span)[span_4](end_span)[span_5](start_span)[span_5](end_span).
* **File Path:** Arabic strings in the file name as a reliable fallback for poorly tagged files[span_6](start_span)[span_6](end_span).
Once detected:
* **Right-to-left page turning** is enabled immediately[span_7](start_span)[span_7](end_span)[span_8](start_span)[span_8](end_span).
* **Touch zones** invert instantly to match RTL orientation without reopening the file[span_9](start_span)[span_9](end_span).
* A quick 2-second toast confirms activation.
### 2. Tailored Arabic Typography (EPUB / Reflowable)
* **Automatic Default Font (Scheherazade New):** Books without an explicit font face automatically adopt **Scheherazade New** upon detection.
* **Auto Line-Height Scaling (130%):** Arabic typefaces feature prominent ascenders, descenders, and vertical diacritics. Setting line-height to 130% prevents overlapping accents across lines.
* **Hyphenation Killer:** Algorithmic Latin hyphenation is automatically disabled for Arabic books, eliminating erratic hyphens slicing Arabic words in half.
* **Auto Right-Alignment:** Reflowable texts are aligned to the right while preserving document integrity.
### 3. Bundled Fonts & System-Wide Synchronization
* **Bundled Typefaces:** Ships with three classical, high-legibility Arabic type families in both Regular and Bold:
  * **Scheherazade New** (Default)
  * **Amiri**
  * **Cairo**
* **Zero-Configuration Installation:** Bundled font files in `assets/` are automatically copied to KOReader's `fonts/` folder on launch, and the internal font cache is reloaded dynamically via `FontList:rebuildFontList()`.
* **System-Wide Application:** Changing the fallback font inside the plugin menu updates the active book and registers the choice globally across KOReader (`settings.reader.lua`).
### 4. PDF & Fixed-Layout Engine Support
* **Safe Application:** For fixed-layout PDF and DjVu documents, the plugin applies RTL page-turning while automatically disabling and greying out incompatible options (font changes, line-height, text alignment) to prevent rendering conflicts[span_10](start_span)[span_10](end_span).
* **Reverse Page Order (Scanned Book Fix):** Scanned heritage books or backwards-digitized PDFs can have their page order flipped end-to-end ($Total \to 1$) via dynamic `page_map` mapping without altering the physical file.
### 5. Research & Reading Tools
* **Enhanced Dictionary Lookup (Tashkeel Stripping):** Strips Arabic vowel marks (تنوين، حركات، شدة) and surrounding punctuation from highlighted words before querying StarDict dictionaries, drastically improving lookup hit rates.
* **Clean Arabic Clippings (RLM Formatting):** Automatically prepends the invisible Unicode Right-to-Left Mark (`\u{200F}`) to bookmarks and highlights, preventing parentheses and punctuation from reversing when notes are exported to Obsidian, Notion, or plain text.
### 6. Dynamic Bilingual UI
The entire interface, descriptions, help strings, and toasts automatically toggle between **Arabic** and **English** based on KOReader's global UI language setting[span_11](start_span)[span_11](end_span).
---
## Menu Structure
Accessible under **Tools (الأدوات) → Arabic Enhancement (تحسينات اللغة العربية)**:

| Option (English) | الخيار (عربي) | Description / الوصف |
| :--- | :--- | :--- |
| **Auto-detect Arabic books** | **اكتشاف الكتب العربية تلقائياً** | Global toggle for automatic Arabic detection on open[span_12](start_span)[span_12](end_span)[span_13](start_span)[span_13](end_span). |
| **Apply Arabic style to this book** | **تطبيق ستايل القراءة العربي على هذا الكتاب** | Manually enforces RTL and typography rules on the current book[span_14](start_span)[span_14](end_span). |
| **Toggle right-to-left for this book** | **تبديل اتجاه التقليب لهذا الكتاب** | Flips page-turn direction for the active document[span_15](start_span)[span_15](end_span)[span_16](start_span)[span_16](end_span). |
| **Reverse page order for this book** | **عكس ترتيب صفحات هذا الكتاب** | Maps reading order backwards ($N \to Total - N + 1$) for mis-scanned books. |
| **Auto-align text to the right** | **محاذاة النص لليمين تلقائياً** | Auto right-aligns reflowable texts (Disabled for PDF)[span_17](start_span)[span_17](end_span). |
| **Auto-disable hyphenation** | **تعطيل فواصل الكلمات اللاتينية تلقائياً** | Disables word-breaking algorithms (Disabled for PDF). |
| **Auto line-height (130%)** | **ضبط تباعد الأسطر تلقائياً (130%)** | Expands line height to accommodate Arabic diacritics (Disabled for PDF). |
| **Enhanced dictionary lookup** | **تحسين البحث في القاموس (إزالة التشكيل)** | Strips tashkeel during word definition queries. |
| **Clean Arabic clippings (RLM)** | **حفظ علامات الترقيم في المقتبسات (RLM)** | Injects RLM markers into highlights and notes. |
| **Default fallback font** | **الخط العربي المعتمد** | Select between Scheherazade New, Amiri, and Cairo. Applies system-wide. |

---
## Gesture Manager (Dispatcher Actions)
Two dispatcher actions are exposed for hardware keys or touchscreen gestures (**Settings → Taps and gestures → Gesture manager**):
* `arabicenhancement_apply_style`: Apply Arabic style to the current book[span_18](start_span)[span_18](end_span).
* `arabicenhancement_toggle_rtl`: Toggle RTL reading order for the current book[span_19](start_span)[span_19](end_span)[span_20](start_span)[span_20](end_span).
---
## Installation
1. Download the latest release archive.
2. Ensure the extracted folder is named exactly: `arabicenhancement.koplugin`
3. Copy `arabicenhancement.koplugin` into your device's KOReader plugins directory[span_21](start_span)[span_21](end_span):

| Device | Path |
| :--- | :--- |
| **Kindle** | `/mnt/us/koreader/plugins/`[span_22](start_span)[span_22](end_span) |
| **Kobo** | `.adds/koreader/plugins/`[span_23](start_span)[span_23](end_span) |
| **PocketBook** | `system/koreader/plugins/`[span_24](start_span)[span_24](end_span) |
| **Android** | `/sdcard/koreader/plugins/`[span_25](start_span)[span_25](end_span) |
| **Desktop (Linux/macOS)** | `~/.config/koreader/plugins/`[span_26](start_span)[span_26](end_span) |

4. Restart KOReader[span_27](start_span)[span_27](end_span).
---
## Directory Structure
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
---
## Compatibility
* Compatible with KOReader releases on **Kindle, Kobo, Android, PocketBook, and Linux/macOS**.
* Compatible with both **LuaJIT** and **Lua 5.3+** runtimes[span_28](start_span)[span_28](end_span).
* Built defensively using `pcall` wrappers to prevent crashes if KOReader internal APIs evolve[span_29](start_span)[span_29](end_span).
* **License:** [AGPL-3.0](LICENSE) (Matching KOReader core)[span_30](start_span)[span_30](end_span).