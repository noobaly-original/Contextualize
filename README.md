# Contextualize

**Contextualize** is a native macOS Menu Bar utility and **Finder Sync Extension** (`FIFinderSync`) that brings customizable, foldable right-click context menu actions to Finder directory backgrounds, folders, and files—complete with a built-in manager to show or hide third-party applications' context menu entries.

---

## Key Features

### 1. Foldable `"New..."` File Creation Menu (`"Yeni..."`)
Right-click on any empty directory background (including Desktop and Finder folders) and hover over **New...** (`Yeni...`) to create valid, ready-to-open documents:
- **Text File (`.txt`)** — Clean UTF-8 plain text file
- **Apple Pages Document (`.pages`)** — Real valid blank Apple Pages document
- **Apple Keynote Presentation (`.key`)** — Real valid blank Apple Keynote presentation
- **Apple Numbers Spreadsheet (`.numbers`)** — Real valid blank Apple Numbers spreadsheet
- **Microsoft Word Document (`.docx`)** — Spec-compliant OpenXML Word package
- **Markdown File (`.md`)** & **Custom Templates** — Attach any custom template file or initial text snippet for any file extension, with automatic duplicate numbering (`Untitled.txt`, `Untitled 2.txt` / `Adsız.txt`, `Adsız 2.txt`).

### 2. Per-Item Folding (`Hover Submenu` vs. `Top-Level`)
- Every menu item has an individual **Fold into Submenu** checkbox:
  - **Checked:** Grouped inside the hover-expandable **New...** (`Yeni...`) or **Quick Actions** (`Hızlı İşlemler`) submenu.
  - **Unchecked:** Displayed directly on the root level of the Finder right-click context menu.
- Includes a master **Fold All into Single Menu** switch if you prefer a single compact entry in Finder.

### 3. Developer & Power-User Quick Actions
- **Open Terminal Here (`Burada Terminal Aç`)** — Spawns a new terminal window directly inside the clicked directory (`macOS Terminal`, `iTerm2`, `Warp`, or `Ghostty`).
- **Open with Application (`Uygulama ile Aç`)** — Pick any `.app` in `/Applications` (such as **Antigravity**, **Zed**, **VS Code**, **Cursor**, **Obsidian**); Contextualize automatically extracts and renders the app's native icon in the context menu and opens the clicked folder with that application.
- **Copy Folder Path (`Klasör Yolunu Kopyala`)** — Copies the POSIX path of the clicked directory or selected item to the clipboard.
- **Custom Shell Commands** — Run any shell command or script with `$CONTEXT_DIR` set to the target directory.

### 4. High-Contrast Dark Mode Icon Colors & Visual Symbol Picker
- **Retina `@2x` Monochrome Symbol Rendering:** Icons are rasterized at `@2x` Retina resolution with 100% layer opacity so multi-layer SF Symbols (like `doc.badge.plus`) never appear dim or black in macOS Dark Mode.
- **11 Built-in Color Swatches:** Apply **White** (default for Dark Mode), **Light Silver**, **Blue**, **Cyan**, **Green**, **Yellow**, **Orange**, **Pink**, **Purple**, **Red**, or **Dark Charcoal** across all icons in one click or individually per item.
- **Visual SF Symbol Picker & Custom Icons:** Choose from a built-in clickable SF Symbol grid, type any SF Symbol name, or pick any `.app`, `.icns`, or `.png` file as an item's icon.

### 5. Third-Party Context Menu Manager (`Other Apps' Menus` / `Diğer Uygulamalar`)
Manage context menu items added by other installed applications directly from Contextualize:
- **FinderSync & Cloud Extensions (`com.apple.FinderSync`, `com.apple.fileprovider-nonui`)** — Toggle entries like **Gemini** (*Add to Gemini*), **Keka** (*Compress with Keka*), and **Google Drive** via `pluginkit`.
- **Quick Actions & Share Menu Extensions (`com.apple.ui-services`, `com.apple.share-services`)** — Toggle extensions from apps like **Notability**, **LocalSend**, and **Telegram**.
- **System Context Menu Services (`NSServices`)** — Toggle application services registered in `pbs.plist`.

### 6. Start at Login Hidden in Menu Bar
- Enable **Start at startup hidden in Menu Bar** (*Bilgisayar açıldığında menü çubuğunda gizli olarak başlat*) from **General & Finder Settings** or directly from the top menu bar icon.
- Automatically configures a macOS `LaunchAgent` (`--background`) so Contextualize starts silently in the menu bar at login without opening a window or Dock icon.

### 7. Bilingual UI (English & Türkçe) + Live Preview
- Automatically follows your macOS system language or lets you switch between **English** and **Türkçe** at any time.
- Includes a **Live Finder Right-Click Preview** pane that reflects your menu structure, icon colors, and active third-party extensions in real time.

---

## Project Structure

```text
Contextualize/
├── Sources/
│   ├── Shared/
│   │   ├── MenuConfiguration.swift      # Codable models, IconColorOption renderer & ConfigStore
│   │   └── ActionExecutor.swift         # File creation engine, Terminal/App launcher & shell runner
│   ├── FinderSyncExtension/
│   │   └── FinderSync.swift             # FIFinderSync extension building dynamic foldable NSMenus
│   └── HostApp/
│       ├── AppMain.swift                # Menu Bar NSStatusItem, LaunchAtLoginManager & IPC listener
│       ├── SettingsWindowView.swift     # SwiftUI customization UI & live Finder context menu preview
│       └── ThirdPartyMenuManager.swift  # Discovery & toggling for 3rd-party appex & NSServices
├── Resources/
│   ├── HostApp-Info.plist               # Host app bundle metadata & custom URL scheme
│   ├── FinderSync-Info.plist            # Finder Sync Extension metadata
│   └── FinderSync.entitlements          # Extension sandbox entitlements
├── scripts/
│   └── generate_app_icon.swift          # Multi-resolution AppIcon.icns generator
├── build.sh                             # Compiles, bundles templates/icons, and signs the .app & .appex
└── install_and_run.sh                   # Installs to /Applications, registers extension, and launches
```

---

## Building & Installing

### Prerequisites
- macOS 13.0 or later
- Xcode Command Line Tools (`xcode-select --install`)

### Build & Run
```zsh
# 1. Build build/ContextMenuStudio.app (includes ContextMenuFinderSync.appex & AppIcon.icns)
./build.sh

# 2. Install to /Applications, enable the Finder Sync extension, and launch
./install_and_run.sh
```

> **Tip:** If the context menu does not appear immediately in Finder after first installation, click **Open macOS Extension Settings** at the bottom of the Contextualize window and ensure **ContextMenu Studio** is enabled under **System Settings → General → Login Items & Extensions → Finder**.

---

## Contributors

- **[@noobaly-original](https://github.com/noobaly-original)** — Creator & Maintainer
- **Antigravity (Google DeepMind)** — Co-Author & Contributor
