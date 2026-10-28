# Contextualize

**Contextualize** is a native macOS Menu Bar utility + **Finder Sync Extension** (`FIFinderSync`) that brings customizable, foldable right-click context menu actions to Finder directory backgrounds, folders, and files—plus a built-in manager to toggle third-party applications' context menu entries.

## Features

- **Foldable `"New..."` Submenu (`"Yeni..."` in Turkish)**:
  - Hover over **New...** (`Yeni...`) when right-clicking an empty directory background in Finder to create real, valid documents:
    - **Text File (`.txt`)** — UTF-8 plain text file
    - **Pages Document (`.pages`)** — Real blank Apple Pages document
    - **Keynote Presentation (`.key`)** — Real blank Apple Keynote presentation
    - **Numbers Spreadsheet (`.numbers`)** — Real blank Apple Numbers spreadsheet
    - **Word Document (`.docx`)** — Valid OpenXML Word document
    - **Markdown File (`.md`)** or any custom file extension / custom template file
- **Per-Item Foldable Toggle**:
  - Every context menu item has a checkbox to toggle whether it is **folded inside a hoverable submenu** (`New...` / `Quick Actions`) or displayed **directly at the top level** of the right-click context menu.
  - Also includes a master **Fold All into Single Menu** option.
- **Built-in Quick Actions**:
  - **Open Terminal Here (`Burada Terminal Aç`)** — Spawns a new macOS Terminal (or iTerm2, Warp, Ghostty) window right inside the clicked directory.
  - **Copy Folder Path (`Klasör Yolunu Kopyala`)** — Copies the POSIX path of the folder/item to the clipboard.
  - **Custom Shell Commands** — Add your own custom scripts/commands with `$CONTEXT_DIR` set to the clicked directory.
- **High-Contrast Dark Mode Icon Colors**:
  - Choose from 11 vibrant icon colors (**White**, **Light Silver**, **Blue**, **Cyan**, **Green**, **Yellow**, **Orange**, **Pink**, **Purple**, **Red**, **Dark Charcoal**) globally or per item, rendered at `@2x` Retina resolution so icons stay crisp in macOS Dark Mode.
- **Third-Party Context Menu Manager (`Other Apps' Menus` / `Diğer Uygulamalar`)**:
  - View and toggle context menu entries added by other installed macOS apps (such as **Gemini**, **Keka**, **Google Drive**, **LocalSend**, **IINA**, **Notability**, etc.) across FinderSync extensions, Quick Actions/Share extensions, and `NSServices`.
- **Bilingual UI (English & Turkish)**:
  - Automatically follows your macOS language or lets you switch between **English** and **Türkçe** at any time, complete with a **Live Finder Right-Click Preview**.

## Building & Installing

```zsh
# Build the app bundle and embedded Finder Sync extension
./build.sh

# Install to /Applications, register the Finder extension, and launch
./install_and_run.sh
```

## Contributors

- **[@noobaly-original](https://github.com/noobaly-original)** — Creator & Maintainer
- **Antigravity (Google DeepMind)** — Co-Author & Contributor
