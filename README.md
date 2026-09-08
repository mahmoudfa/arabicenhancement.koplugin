# Arabic Enhancement — `arabic_enhancement.koplugin`

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![KOReader Plugin](https://img.shields.io/badge/KOReader-Plugin-green.svg)](https://github.com/koreader/koreader)

A [KOReader](https://github.com/koreader/koreader) plugin that automatically detects Arabic-language documents and applies optimized reading settings—without overriding your manual preferences.

## Features

When an Arabic book is detected (via metadata, TOC, or text byte-scanning), the plugin automatically applies:
* **Right-to-left (RTL) page turning** and inverted touch zones.
* **Right text alignment** (for reflowable CREngine documents like EPUB, MOBI, FB2).
* **Smart fallback fonts**, prioritizing the book's embedded fonts while dynamically applying a configurable fallback Arabic font from your KOReader system fonts directory.

## Menu & Controls

Access the plugin settings via the top reader menu under **Arabic Enhancement**:
* **Auto-detect Arabic books:** Global toggle for the detection engine.
* **Auto-align text to right:** Enable or disable automatic text alignment.
* **Toggle RTL for current book:** Instantly switch directions manually.
* **Fallback Arabic Font:** Select your preferred backup font from a dynamically generated list of your installed KOReader fonts.

## Installation

1. Go to the **[Releases](../../releases)** page of this repository.
2. Download the latest `arabic_enhancement.koplugin.zip` file.
3. Extract the downloaded ZIP file. You should get a folder named exactly **`arabic_enhancement.koplugin`**.
4. Copy this folder into your device's KOReader plugins directory depending on your device:
   * **Kindle:** `/mnt/us/koreader/plugins/`
   * **Kobo:** `.adds/koreader/plugins/`
   * **PocketBook:** `system/koreader/plugins/`
   * **Android:** `/sdcard/koreader/plugins/`
   * **Desktop (Linux/macOS):** `~/.config/koreader/plugins/`
5. Restart KOReader. You will find the plugin settings in the top reader menu.

## License

Distributed under the MIT License. See `LICENSE` for more information.
