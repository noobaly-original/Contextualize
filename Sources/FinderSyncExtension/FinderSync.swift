import Cocoa
import FinderSync

@objc(FinderSync)
class FinderSync: FIFinderSync {
    private var config: MenuConfiguration
    private var itemMap: [Int: ContextMenuItem] = [:]

    override init() {
        self.config = ConfigStore.shared.load()
        super.init()

        updateMonitoredDirectories()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleConfigUpdated(_:)),
            name: ConfigConstants.configUpdatedNotification,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        // Request latest config from host app if running
        DistributedNotificationCenter.default().postNotificationName(
            ConfigConstants.requestConfigNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handleConfigUpdated(_ notification: Notification) {
        if let jsonString = notification.object as? String,
           let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(MenuConfiguration.self, from: data) {
            self.config = decoded
            ConfigStore.shared.save(decoded, broadcast: false)
        } else {
            self.config = ConfigStore.shared.load()
        }
        updateMonitoredDirectories()
    }

    private func updateMonitoredDirectories() {
        var urls = Set<URL>()
        for path in config.monitoredDirectories {
            urls.insert(URL(fileURLWithPath: path))
        }
        if urls.isEmpty {
            urls.insert(URL(fileURLWithPath: "/"))
        }
        FIFinderSyncController.default().directoryURLs = urls
    }

    override var toolbarItemName: String {
        return config.isTurkish ? "Yeni Dosya & İşlemler" : "New File & Actions"
    }

    override var toolbarItemToolTip: String {
        return config.isTurkish
            ? "Bu klasörde yeni dosya oluşturun veya hızlı işlem çalıştırın"
            : "Create a new file or run quick actions in this folder"
    }

    override var toolbarItemImage: NSImage {
        let img = NSImage(systemSymbolName: "plus.rectangle.on.folder", accessibilityDescription: "New File")
            ?? NSImage(size: NSSize(width: 16, height: 16))
        img.isTemplate = true
        return img
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Reload latest config if available on disk
        let diskConfig = ConfigStore.shared.load()
        if diskConfig != self.config {
            self.config = diskConfig
        }

        switch menuKind {
        case .contextualMenuForContainer:
            guard config.showOnFolderBackground else { return nil }
        case .contextualMenuForItems:
            let selected = FIFinderSyncController.default().selectedItemURLs() ?? []
            if selected.isEmpty {
                guard config.showOnFolderBackground else { return nil }
            } else {
                var isDir: ObjCBool = false
                let firstIsDir = FileManager.default.fileExists(atPath: selected[0].path, isDirectory: &isDir) && isDir.boolValue
                if firstIsDir && !config.showOnSelectedFolders {
                    return nil
                }
                if !firstIsDir && !config.showOnSelectedFiles {
                    return nil
                }
            }
        case .toolbarItemMenu:
            break
        case .contextualMenuForSidebar:
            guard config.showOnSelectedFolders else { return nil }
        @unknown default:
            break
        }

        return buildContextMenu()
    }

    private func buildContextMenu() -> NSMenu? {
        let enabledItems = config.items.filter { $0.isEnabled }
        guard !enabledItems.isEmpty else { return nil }

        let rootMenu = NSMenu(title: "")
        rootMenu.autoenablesItems = false
        itemMap.removeAll()

        let isTR = config.isTurkish

        if config.foldAllIntoSingleMenu {
            let parentItem = NSMenuItem(title: config.localizedNewMenuTitle, action: nil, keyEquivalent: "")
            parentItem.image = config.submenuIconColor.renderedSymbolImage(name: "plus.square.on.square")
            let subMenu = NSMenu(title: config.localizedNewMenuTitle)
            subMenu.autoenablesItems = false

            for (index, item) in enabledItems.enumerated() {
                let tag = index + 100
                itemMap[tag] = item
                subMenu.addItem(makeMenuItem(for: item, tag: tag, isTR: isTR))
            }
            parentItem.submenu = subMenu
            rootMenu.addItem(parentItem)
            return rootMenu
        }

        // Group items according to each item's `isFolded` and `submenuGroup` settings
        let foldedNewItems = enabledItems.filter { $0.isFolded && $0.submenuGroup == .newMenu }
        let foldedQuickActionItems = enabledItems.filter { $0.isFolded && $0.submenuGroup == .quickActions }
        let unfoldedItems = enabledItems.filter { !$0.isFolded }

        var nextTag = 100

        // 1. Foldable "New..." submenu (hover over "New..." / "Yeni..." to see all file creation options)
        if !foldedNewItems.isEmpty {
            let newParent = NSMenuItem(title: config.localizedNewMenuTitle, action: nil, keyEquivalent: "")
            newParent.image = config.submenuIconColor.renderedSymbolImage(name: "doc.badge.plus")
            let newSubmenu = NSMenu(title: config.localizedNewMenuTitle)
            newSubmenu.autoenablesItems = false

            for item in foldedNewItems {
                let tag = nextTag
                nextTag += 1
                itemMap[tag] = item
                newSubmenu.addItem(makeMenuItem(for: item, tag: tag, isTR: isTR))
            }
            newParent.submenu = newSubmenu
            rootMenu.addItem(newParent)
        }

        // 2. Foldable "Quick Actions" submenu (if any quick action items have `isFolded` checked)
        if !foldedQuickActionItems.isEmpty {
            let qaParent = NSMenuItem(title: config.localizedQuickActionsTitle, action: nil, keyEquivalent: "")
            qaParent.image = config.submenuIconColor.renderedSymbolImage(name: "bolt.circle")
            let qaSubmenu = NSMenu(title: config.localizedQuickActionsTitle)
            qaSubmenu.autoenablesItems = false

            for item in foldedQuickActionItems {
                let tag = nextTag
                nextTag += 1
                itemMap[tag] = item
                qaSubmenu.addItem(makeMenuItem(for: item, tag: tag, isTR: isTR))
            }
            qaParent.submenu = qaSubmenu
            rootMenu.addItem(qaParent)
        }

        // 3. Unfolded top-level items (placed directly on the context menu)
        for item in unfoldedItems {
            let tag = nextTag
            nextTag += 1
            itemMap[tag] = item
            rootMenu.addItem(makeMenuItem(for: item, tag: tag, isTR: isTR))
        }

        return rootMenu
    }

    private func makeMenuItem(for item: ContextMenuItem, tag: Int, isTR: Bool) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: item.localizedTitle(isTR: isTR),
            action: #selector(handleMenuItemAction(_:)),
            keyEquivalent: ""
        )
        menuItem.target = self
        menuItem.tag = tag
        menuItem.isEnabled = true
        menuItem.image = item.resolvedIcon()
        return menuItem
    }

    @objc private func handleMenuItemAction(_ sender: NSMenuItem) {
        guard let item = itemMap[sender.tag] else { return }

        let targetedURL = FIFinderSyncController.default().targetedURL()
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []

        // Determine the best target folder path:
        // - If user right-clicked on a single folder, target that folder
        // - If user right-clicked on empty folder background, target `targetedURL`
        let targetDirPath: String
        if selectedURLs.count == 1 {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: selectedURLs[0].path, isDirectory: &isDir), isDir.boolValue {
                targetDirPath = selectedURLs[0].path
            } else {
                targetDirPath = targetedURL?.path ?? selectedURLs[0].deletingLastPathComponent().path
            }
        } else {
            targetDirPath = targetedURL?.path ?? selectedURLs.first?.deletingLastPathComponent().path ?? ConfigStore.shared.realUserHomePath
        }

        let payload = ActionExecutionPayload(
            itemID: item.id,
            targetDirectoryPath: targetDirPath,
            selectedPaths: selectedURLs.map { $0.path }
        )

        // If the host Menu Bar app is running, dispatch to it via DistributedNotificationCenter
        let hostApps = NSRunningApplication.runningApplications(withBundleIdentifier: ConfigConstants.appBundleID)
        if !hostApps.isEmpty,
           let data = try? JSONEncoder().encode(payload),
           let jsonString = String(data: data, encoding: .utf8) {
            DistributedNotificationCenter.default().postNotificationName(
                ConfigConstants.executeActionNotification,
                object: jsonString,
                userInfo: nil,
                deliverImmediately: true
            )
            return
        }

        // Otherwise try direct execution first; if host app is needed, open via custom URL scheme
        if !ActionExecutor.shared.execute(payload: payload, config: config) {
            if let data = try? JSONEncoder().encode(payload) {
                let base64 = data.base64EncodedString()
                if var comps = URLComponents(string: "\(ConfigConstants.urlScheme)://execute") {
                    comps.queryItems = [URLQueryItem(name: "payload", value: base64)]
                    if let url = comps.url {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
