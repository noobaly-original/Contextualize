import Cocoa
import SwiftUI

final class ExtensionManager {
    static let shared = ExtensionManager()

    private init() {}

    var bundledExtensionPath: String {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/PlugIns/ContextMenuFinderSync.appex")
            .path
    }

    func enableAndRefreshExtension() {
        let appexPath = bundledExtensionPath
        DispatchQueue.global(qos: .userInitiated).async {
            if FileManager.default.fileExists(atPath: appexPath) {
                self.runProcess("/usr/bin/pluginkit", arguments: ["-a", appexPath])
            }
            self.runProcess("/usr/bin/pluginkit", arguments: ["-e", "use", "-i", ConfigConstants.extensionBundleID])
        }
    }

    func openSystemExtensionsSettings() {
        let candidateURLs = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.ExtensionsPreferences"
        ]
        for str in candidateURLs {
            if let url = URL(string: str), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func runProcess(_ launchPath: String, arguments: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
    }
}

enum FinderSelectionHelper {
    static func currentFinderDirectoryPath() -> String {
        let scriptSource = """
        tell application "Finder"
            if (count of Finder windows) > 0 then
                try
                    set targetFolder to (target of front Finder window) as alias
                    return POSIX path of targetFolder
                end try
            end if
            return POSIX path of (path to desktop folder)
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var errorDict: NSDictionary?
            let result = script.executeAndReturnError(&errorDict)
            if let path = result.stringValue, !path.isEmpty {
                return path
            }
        }
        let desktop = (ConfigStore.shared.realUserHomePath as NSString).appendingPathComponent("Desktop")
        return desktop
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var viewModel = MenuSettingsViewModel()
    private var statusMenuItemsMap: [Int: ContextMenuItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure initial configuration is saved & synced to container paths
        ConfigStore.shared.save(viewModel.config, broadcast: true)

        // Register & enable our Finder Sync Extension
        ExtensionManager.shared.enableAndRefreshExtension()

        setupEditMenu()
        setupStatusItem()
        setupDistributedNotifications()

        viewModel.onConfigChanged = { [weak self] in
            self?.rebuildStatusBarMenu()
        }

        // Show Settings window on launch unless launched silently in background
        if !CommandLine.arguments.contains("--background") {
            showSettingsWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == ConfigConstants.urlScheme else { continue }
            if url.host == "execute",
               let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let payloadBase64 = comps.queryItems?.first(where: { $0.name == "payload" })?.value,
               let data = Data(base64Encoded: payloadBase64),
               let payload = try? JSONDecoder().decode(ActionExecutionPayload.self, from: data) {
                ActionExecutor.shared.execute(payload: payload, config: viewModel.config)
            } else if url.host == "settings" {
                showSettingsWindow()
            }
        }
    }

    private func setupDistributedNotifications() {
        let center = DistributedNotificationCenter.default()

        center.addObserver(
            self,
            selector: #selector(handleExecuteActionNotification(_:)),
            name: ConfigConstants.executeActionNotification,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        center.addObserver(
            self,
            selector: #selector(handleRequestConfigNotification(_:)),
            name: ConfigConstants.requestConfigNotification,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func handleExecuteActionNotification(_ notification: Notification) {
        guard let jsonString = notification.object as? String,
              let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ActionExecutionPayload.self, from: data) else {
            return
        }
        ActionExecutor.shared.execute(payload: payload, config: viewModel.config)
    }

    @objc private func handleRequestConfigNotification(_ notification: Notification) {
        ConfigStore.shared.save(viewModel.config, broadcast: true)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "plus.rectangle.on.folder.fill", accessibilityDescription: "ContextMenu Studio")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "ContextMenu Studio"
        }
        rebuildStatusBarMenu()
    }

    func rebuildStatusBarMenu() {
        let menu = NSMenu()
        let config = viewModel.config
        let isTR = config.isTurkish
        statusMenuItemsMap.removeAll()

        let headerItem = NSMenuItem(
            title: isTR ? "ContextMenu Studio (Aktif Finder Klasörü)" : "ContextMenu Studio (Active Finder Folder)",
            action: nil,
            keyEquivalent: ""
        )
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        let enabledItems = config.items.filter { $0.isEnabled }
        let foldedNew = enabledItems.filter { $0.isFolded && $0.submenuGroup == .newMenu }
        let foldedQA = enabledItems.filter { $0.isFolded && $0.submenuGroup == .quickActions }
        let unfolded = enabledItems.filter { !$0.isFolded }

        var nextTag = 1000

        if config.foldAllIntoSingleMenu {
            let parent = NSMenuItem(title: config.localizedNewMenuTitle, action: nil, keyEquivalent: "")
            parent.image = NSImage(systemSymbolName: "plus.square.on.square", accessibilityDescription: nil)
            let sub = NSMenu(title: config.localizedNewMenuTitle)
            for item in enabledItems {
                let tag = nextTag
                nextTag += 1
                statusMenuItemsMap[tag] = item
                sub.addItem(makeStatusMenuItem(item: item, tag: tag, isTR: isTR))
            }
            parent.submenu = sub
            menu.addItem(parent)
        } else {
            if !foldedNew.isEmpty {
                let parent = NSMenuItem(title: config.localizedNewMenuTitle, action: nil, keyEquivalent: "")
                parent.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
                let sub = NSMenu(title: config.localizedNewMenuTitle)
                for item in foldedNew {
                    let tag = nextTag
                    nextTag += 1
                    statusMenuItemsMap[tag] = item
                    sub.addItem(makeStatusMenuItem(item: item, tag: tag, isTR: isTR))
                }
                parent.submenu = sub
                menu.addItem(parent)
            }

            if !foldedQA.isEmpty {
                let parent = NSMenuItem(title: config.localizedQuickActionsTitle, action: nil, keyEquivalent: "")
                parent.image = NSImage(systemSymbolName: "bolt.circle", accessibilityDescription: nil)
                let sub = NSMenu(title: config.localizedQuickActionsTitle)
                for item in foldedQA {
                    let tag = nextTag
                    nextTag += 1
                    statusMenuItemsMap[tag] = item
                    sub.addItem(makeStatusMenuItem(item: item, tag: tag, isTR: isTR))
                }
                parent.submenu = sub
                menu.addItem(parent)
            }

            for item in unfolded {
                let tag = nextTag
                nextTag += 1
                statusMenuItemsMap[tag] = item
                menu.addItem(makeStatusMenuItem(item: item, tag: tag, isTR: isTR))
            }
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: isTR ? "Sağ Tık Menüsünü Özelleştir..." : "Customize Context Menu...",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        let refreshItem = NSMenuItem(
            title: isTR ? "Finder Uzantısını Yenile" : "Refresh Finder Extension",
            action: #selector(refreshExtensionAction),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        refreshItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: isTR ? "ContextMenu Studio'dan Çık" : "Quit ContextMenu Studio",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeStatusMenuItem(item: ContextMenuItem, tag: Int, isTR: Bool) -> NSMenuItem {
        let mi = NSMenuItem(
            title: item.localizedTitle(isTR: isTR),
            action: #selector(handleStatusBarActionItem(_:)),
            keyEquivalent: ""
        )
        mi.target = self
        mi.tag = tag
        mi.image = item.resolvedIcon()
        return mi
    }

    @objc private func handleStatusBarActionItem(_ sender: NSMenuItem) {
        guard let item = statusMenuItemsMap[sender.tag] else { return }
        let targetDir = FinderSelectionHelper.currentFinderDirectoryPath()
        ActionExecutor.shared.execute(item: item, targetDirectoryPath: targetDir, config: viewModel.config)
    }

    @objc private func openSettingsAction() {
        showSettingsWindow()
    }

    @objc private func refreshExtensionAction() {
        viewModel.refreshFinderExtension()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    func showSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        if settingsWindow == nil {
            let contentView = SettingsWindowView(viewModel: viewModel)
            let hostingController = NSHostingController(rootView: contentView)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 890, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "ContextMenu Studio"
            window.contentViewController = hostingController
            window.center()
            window.setFrameAutosaveName("ContextMenuStudioSettingsWindow")
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Return to menu-bar-only mode (no Dock icon clutter) when settings window is closed
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupEditMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit ContextMenu Studio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}

@main
struct ContextMenuStudioApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
