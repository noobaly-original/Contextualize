import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class MenuSettingsViewModel: ObservableObject {
    @Published var config: MenuConfiguration {
        didSet {
            if !isLoading {
                ConfigStore.shared.save(config, broadcast: true)
                onConfigChanged?()
            }
        }
    }

    @Published var selectedItemID: UUID?
    @Published var selectedTab: Int = 0
    @Published var editingItem: ContextMenuItem?
    @Published var statusMessage: String?

    var onConfigChanged: (() -> Void)?
    private var isLoading = false

    init() {
        self.isLoading = true
        let loaded = ConfigStore.shared.load()
        self.config = loaded
        self.selectedItemID = loaded.items.first?.id
        self.isLoading = false
    }

    var isTR: Bool {
        config.isTurkish
    }

    func reloadFromDisk() {
        isLoading = true
        config = ConfigStore.shared.load()
        isLoading = false
    }

    func addFileItem() {
        let newItem = ContextMenuItem(
            titleEN: "New File (.txt)",
            titleTR: "Yeni Dosya (.txt)",
            iconSymbol: "doc.badge.plus",
            useSystemFileIcon: true,
            isEnabled: true,
            isFolded: true,
            submenuGroup: .newMenu,
            actionKind: .createFile,
            fileExtension: "txt",
            baseFileNameEN: "Untitled",
            baseFileNameTR: "Adsız",
            templateKind: .plainText
        )
        config.items.append(newItem)
        selectedItemID = newItem.id
        editingItem = newItem
    }

    func addActionItem() {
        let newItem = ContextMenuItem(
            titleEN: "Custom Terminal Command",
            titleTR: "Özel Terminal Komutu",
            iconSymbol: "terminal",
            useSystemFileIcon: false,
            isEnabled: true,
            isFolded: false,
            submenuGroup: .quickActions,
            actionKind: .customCommand,
            customShellCommand: "open -a Terminal \"$CONTEXT_DIR\""
        )
        config.items.append(newItem)
        selectedItemID = newItem.id
        editingItem = newItem
    }

    func deleteItem(id: UUID) {
        config.items.removeAll { $0.id == id }
        if selectedItemID == id {
            selectedItemID = config.items.first?.id
        }
    }

    func moveItem(at index: Int, direction: Int) {
        let targetIndex = index + direction
        guard targetIndex >= 0 && targetIndex < config.items.count else { return }
        config.items.swapAt(index, targetIndex)
    }

    func updateItem(_ updated: ContextMenuItem) {
        if let idx = config.items.firstIndex(where: { $0.id == updated.id }) {
            config.items[idx] = updated
        }
    }

    func applyIconColorToAll(_ color: IconColorOption) {
        var copy = config
        copy.submenuIconColor = color
        for i in copy.items.indices {
            copy.items[i].iconColor = color
        }
        config = copy
        showFlash(isTR ? "İkon rengi tüm öğelere uygulandı: \(color.label(isTR: true))" : "Applied icon color to all items: \(color.label(isTR: false))")
    }

    func resetToDefaults() {
        let currentLang = config.language
        var defaults = MenuConfiguration()
        defaults.language = currentLang
        config = defaults
        selectedItemID = config.items.first?.id
        showFlash(isTR ? "Varsayılan ayarlara sıfırlandı." : "Reset to default settings.")
    }

    func refreshFinderExtension() {
        ConfigStore.shared.save(config, broadcast: true)
        ExtensionManager.shared.enableAndRefreshExtension()
        showFlash(isTR ? "Finder uzantısı yenilendi!" : "Finder extension refreshed!")
    }

    func showFlash(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.statusMessage == message {
                self?.statusMessage = nil
            }
        }
    }
}

struct SettingsWindowView: View {
    @ObservedObject var viewModel: MenuSettingsViewModel
    @ObservedObject var thirdPartyManager = ThirdPartyMenuManager.shared

    var isTR: Bool { viewModel.isTR }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.blue.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus.rectangle.on.folder.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isTR ? "ContextMenu Studio — Sağ Tık Menüsü" : "ContextMenu Studio — Finder Context Menu")
                        .font(.system(size: 16, weight: .bold))
                    Text(isTR
                         ? "Klasör arka planına sağ tıkladığınızda görünen katlanabilir \"Yeni...\" menülerini ve diğer uygulamaların sağ tık öğelerini yönetin."
                         : "Customize foldable \"New...\" items and control which third-party apps appear in your Finder context menu.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("", selection: $viewModel.config.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .frame(width: 190)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Split View: Left = Items & Settings, Right = Live macOS Context Menu Preview
            HSplitView {
                VStack(spacing: 0) {
                    Picker("", selection: $viewModel.selectedTab) {
                        Text(isTR ? "Menü Öğeleri ve Katlama" : "Menu Items & Folding").tag(0)
                        Text(isTR ? "Diğer Uygulamalar" : "Other Apps' Menus").tag(1)
                        Text(isTR ? "Genel ve Finder Ayarları" : "General & Finder Settings").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(14)

                    Divider()

                    if viewModel.selectedTab == 0 {
                        itemsListTab
                    } else if viewModel.selectedTab == 1 {
                        otherAppsMenusTab
                    } else {
                        generalSettingsTab
                    }
                }
                .frame(minWidth: 500, idealWidth: 560)

                // Right Column: Live Interactive Context Menu Preview
                livePreviewPanel
                    .frame(minWidth: 300, idealWidth: 330, maxWidth: 380)
            }
            .onAppear {
                if thirdPartyManager.entries.isEmpty {
                    thirdPartyManager.refreshEntries()
                }
            }

            Divider()

            // Footer Bar
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.refreshFinderExtension()
                }) {
                    Label(
                        isTR ? "Finder Menüsünü Şimdi Yenile" : "Sync & Refresh Finder Menu",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .controlSize(.regular)

                Button(action: {
                    ExtensionManager.shared.openSystemExtensionsSettings()
                }) {
                    Label(
                        isTR ? "macOS Uzantı Ayarlarını Aç" : "Open macOS Extension Settings",
                        systemImage: "gearshape"
                    )
                }
                .controlSize(.regular)

                if let msg = viewModel.statusMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }

                Spacer()

                Button(role: .destructive, action: {
                    viewModel.resetToDefaults()
                }) {
                    Text(isTR ? "Varsayılanlara Sıfırla" : "Reset to Defaults")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .sheet(item: $viewModel.editingItem) { item in
            ItemEditorSheet(
                editorModel: ItemEditorViewModel(item: item),
                isTR: isTR,
                onSave: { updated in
                    viewModel.updateItem(updated)
                    viewModel.editingItem = nil
                },
                onCancel: {
                    viewModel.editingItem = nil
                }
            )
        }
    }

    // MARK: - Items List Tab
    private var itemsListTab: some View {
        VStack(spacing: 0) {
            // Folding & Icon Color explanation + quick color bar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.gearshape")
                        .foregroundColor(.accentColor)
                    Text(isTR
                         ? "İpucu: \"Alt Menüye Katla (Hover)\" kutusu işaretli öğeler, üzerine gelince açılan \"\(viewModel.config.localizedNewMenuTitle)\" menüsü içinde gruplanır."
                         : "Tip: Items with \"Fold into Submenu (Hover)\" checked are grouped inside \"\(viewModel.config.localizedNewMenuTitle)\" when hovering.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    Text(isTR ? "İkon Rengi (Koyu Mod İçin):" : "Icon Color (Dark Mode Friendly):")
                        .font(.system(size: 11.5, weight: .semibold))

                    ForEach(IconColorOption.allCases) { colorOpt in
                        Button(action: {
                            viewModel.applyIconColorToAll(colorOpt)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(nsColor: colorOpt.nsColor))
                                    .frame(width: 18, height: 18)
                                Circle()
                                    .stroke(
                                        viewModel.config.submenuIconColor == colorOpt ? Color.accentColor : Color.primary.opacity(0.25),
                                        lineWidth: viewModel.config.submenuIconColor == colorOpt ? 2.5 : 1
                                    )
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .buttonStyle(.plain)
                        .help(colorOpt.label(isTR: isTR))
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.08))

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.config.items.enumerated()), id: \.element.id) { index, item in
                        MenuItemRowView(
                            item: item,
                            index: index,
                            totalCount: viewModel.config.items.count,
                            isTR: isTR,
                            newMenuLabel: viewModel.config.localizedNewMenuTitle,
                            quickActionsLabel: viewModel.config.localizedQuickActionsTitle,
                            onToggleEnabled: { enabled in
                                var copy = item
                                copy.isEnabled = enabled
                                viewModel.updateItem(copy)
                            },
                            onToggleFolded: { folded in
                                var copy = item
                                copy.isFolded = folded
                                viewModel.updateItem(copy)
                            },
                            onSelectColor: { newColor in
                                var copy = item
                                copy.iconColor = newColor
                                if copy.actionKind == .createFile && copy.useSystemFileIcon {
                                    // If user picks a custom color on a file item, switch to colored symbol so the color shows!
                                    copy.useSystemFileIcon = false
                                }
                                viewModel.updateItem(copy)
                            },
                            onMoveUp: {
                                viewModel.moveItem(at: index, direction: -1)
                            },
                            onMoveDown: {
                                viewModel.moveItem(at: index, direction: 1)
                            },
                            onEdit: {
                                viewModel.editingItem = item
                            },
                            onDelete: {
                                viewModel.deleteItem(id: item.id)
                            }
                        )
                    }
                }
                .padding(14)
            }

            Divider()

            // Add Item Toolbar
            HStack(spacing: 10) {
                Button(action: { viewModel.addFileItem() }) {
                    Label(isTR ? "+ Yeni Dosya Türü Ekle" : "+ Add New File Type", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button(action: { viewModel.addActionItem() }) {
                    Label(isTR ? "+ Hızlı İşlem / Terminal Ekle" : "+ Add Quick Action / Command", systemImage: "terminal")
                }
                .buttonStyle(.bordered)

                Spacer()

                Toggle(
                    isTR ? "Tümünü Tek Menüsünde Katla" : "Fold All into Single Menu",
                    isOn: $viewModel.config.foldAllIntoSingleMenu
                )
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Other Applications' Context Menus Tab
    private var otherAppsMenusTab: some View {
        VStack(spacing: 0) {
            // Top info & filter bar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .foregroundColor(.accentColor)
                    Text(isTR
                         ? "Diğer uygulamaların (Gemini, Keka, Google Drive, LocalSend, IINA vb.) Finder sağ tık menüsündeki görünürlüğünü buradan açıp kapatabilirsiniz."
                         : "Toggle whether other applications (such as Gemini, Keka, Google Drive, LocalSend, IINA, etc.) show their entries in the Finder context menu.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(
                            isTR ? "Uygulama veya uzantı ara..." : "Search application or extension...",
                            text: $thirdPartyManager.searchQuery
                        )
                        .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))

                    Button(action: {
                        thirdPartyManager.refreshEntries()
                    }) {
                        Label(isTR ? "Yenile" : "Refresh", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)

                    Button(action: {
                        thirdPartyManager.restartFinder()
                        viewModel.showFlash(isTR ? "Finder yeniden başlatıldı." : "Finder restarted.")
                    }) {
                        Label(isTR ? "Finder'ı Yeniden Başlat" : "Restart Finder", systemImage: "finder")
                    }
                    .controlSize(.small)
                    .help(isTR
                          ? "Bazı üçüncü parti uzantıların gizlenmesi için Finder'ın yeniden başlatılması gerekebilir."
                          : "Restart Finder to immediately flush cached third-party context menu items.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.08))

            Divider()

            if thirdPartyManager.isScanning {
                VStack(spacing: 10) {
                    Spacer()
                    ProgressView()
                    Text(isTR ? "Uygulama sağ tık uzantıları taranıyor..." : "Scanning installed context menu extensions...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(ThirdPartyExtensionCategory.allCases) { category in
                            let categoryEntries = filteredThirdPartyEntries(for: category)
                            if !categoryEntries.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category.title(isTR: isTR))
                                            .font(.system(size: 13, weight: .bold))
                                        Text(category.subtitle(isTR: isTR))
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 4)

                                    ForEach(categoryEntries) { entry in
                                        ThirdPartyEntryRowView(
                                            entry: entry,
                                            isTR: isTR,
                                            onToggle: { enabled in
                                                _ = thirdPartyManager.toggleEntry(entry, enabled: enabled)
                                                let stateText = enabled
                                                    ? (isTR ? "Etkinleştirildi" : "Enabled")
                                                    : (isTR ? "Gizlendi" : "Hidden")
                                                viewModel.showFlash("\(entry.appName): \(stateText)")
                                            },
                                            onRevealInFinder: {
                                                NSWorkspace.shared.selectFile(entry.pluginPath, inFileViewerRootedAtPath: "/Applications")
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private func filteredThirdPartyEntries(for category: ThirdPartyExtensionCategory) -> [ThirdPartyMenuEntry] {
        let query = thirdPartyManager.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return thirdPartyManager.entries.filter { entry in
            guard entry.category == category else { return false }
            guard !query.isEmpty else { return true }
            return entry.appName.lowercased().contains(query)
                || entry.entryTitle.lowercased().contains(query)
                || entry.bundleIdentifier.lowercased().contains(query)
        }
    }

    // MARK: - General Settings Tab
    private var generalSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox(label: Label(isTR ? "Katlanabilir Alt Menü Başlıkları" : "Foldable Submenu Titles", systemImage: "menubar.rectangle")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(isTR ? "\"Yeni...\" Başlığı (İngilizce):" : "\"New...\" Title (English):")
                                .frame(width: 200, alignment: .leading)
                            TextField("New...", text: $viewModel.config.newMenuTitleEN)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text(isTR ? "\"Yeni...\" Başlığı (Türkçe):" : "\"New...\" Title (Turkish):")
                                .frame(width: 200, alignment: .leading)
                            TextField("Yeni...", text: $viewModel.config.newMenuTitleTR)
                                .textFieldStyle(.roundedBorder)
                        }
                        Divider()
                        HStack {
                            Text(isTR ? "Hızlı İşlemler Başlığı (EN):" : "Quick Actions Title (EN):")
                                .frame(width: 200, alignment: .leading)
                            TextField("Quick Actions", text: $viewModel.config.quickActionsTitleEN)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text(isTR ? "Hızlı İşlemler Başlığı (TR):" : "Quick Actions Title (TR):")
                                .frame(width: 200, alignment: .leading)
                            TextField("Hızlı İşlemler", text: $viewModel.config.quickActionsTitleTR)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(10)
                }

                GroupBox(label: Label(isTR ? "Menünün Görüneceği Yerler" : "Where to Show Context Menu", systemImage: "cursorarrow.click.2")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            isTR ? "Boş klasör arka planına sağ tıklandığında (Masaüstü ve Finder klasörleri)" : "When right-clicking empty folder background (Desktop & Finder folders)",
                            isOn: $viewModel.config.showOnFolderBackground
                        )
                        Toggle(
                            isTR ? "Bir klasör simgesine sağ tıklandığında" : "When right-clicking a folder icon",
                            isOn: $viewModel.config.showOnSelectedFolders
                        )
                        Toggle(
                            isTR ? "Bir dosyaya sağ tıklandığında (bulunduğu klasörde işlem yapar)" : "When right-clicking a file (operates in its parent folder)",
                            isOn: $viewModel.config.showOnSelectedFiles
                        )
                        Divider()
                        Toggle(
                            isTR ? "Oluşturulan yeni dosyayı Finder'da otomatik seç / vurgula" : "Automatically highlight/select newly created file in Finder",
                            isOn: $viewModel.config.revealCreatedFileInFinder
                        )
                    }
                    .padding(10)
                }

                GroupBox(label: Label(isTR ? "Varsayılan Terminal Uygulaması" : "Preferred Terminal Application", systemImage: "terminal.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(isTR ? "Terminal Uygulaması:" : "Terminal App:", selection: $viewModel.config.terminalAppBundleID) {
                            Text("macOS Terminal (com.apple.Terminal)").tag("com.apple.Terminal")
                            Text("iTerm2 (com.googlecode.iterm2)").tag("com.googlecode.iterm2")
                            Text("Warp (dev.warp.Warp-Stable)").tag("dev.warp.Warp-Stable")
                            Text("Ghostty (com.mitchellh.ghostty)").tag("com.mitchellh.ghostty")
                        }
                        Text(isTR
                             ? "\"Burada Terminal Aç\" tıklandığında seçilen klasör doğrudan bu terminal uygulamasında açılır."
                             : "Clicking \"Open Terminal Here\" opens the target directory directly in this terminal app.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Live Interactive Context Menu Preview
    private var livePreviewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(.accentColor)
                Text(isTR ? "Canlı Finder Sağ Tık Önizlemesi" : "Live Finder Right-Click Preview")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)

            Text(isTR
                 ? "Finder'da boş bir klasör alanına sağ tıkladığınızda menünüz tam olarak böyle görünecektir:"
                 : "Here is how your Finder context menu looks when right-clicking an empty directory background:")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            // Simulated macOS Dark Context Menu matching user's screenshot
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Simulated standard macOS items (dimmed)
                    simulatedStandardRow(isTR ? "Yeni Klasör" : "New Folder")
                    simulatedStandardRow(isTR ? "Öğeyi Yapıştır" : "Paste Item")
                    Divider().padding(.vertical, 3)
                    simulatedStandardRow(isTR ? "Bilgi Ver" : "Get Info")
                    Divider().padding(.vertical, 3)
                    simulatedStandardRow(isTR ? "Görüntü" : "View", hasChevron: true)
                    simulatedStandardRow(isTR ? "Grupları Kullan" : "Use Stacks")
                    simulatedStandardRow(isTR ? "Şuna Göre Sırala:" : "Sort By", hasChevron: true)
                    simulatedStandardRow(isTR ? "Görüntü Seçeneklerini Göster" : "Show View Options")

                    Divider().padding(.vertical, 4)

                    // Our Dynamic Context Menu Items
                    previewCustomItemsSection

                    // Enabled Third-Party FinderSync Apps (e.g. Gemini, Keka, Google Drive)
                    let activeThirdParty = thirdPartyManager.entries.filter { $0.category == .finderSync && $0.isEnabled }
                    if !activeThirdParty.isEmpty {
                        Divider().padding(.vertical, 3)
                        ForEach(activeThirdParty) { tp in
                            HStack(spacing: 8) {
                                Image(nsImage: tp.appIcon)
                                    .resizable()
                                    .frame(width: 15, height: 15)
                                Text(tp.entryTitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            Spacer()
        }
        .background(Color(NSColor.underPageBackgroundColor).opacity(0.45))
    }

    private func simulatedStandardRow(_ title: String, hasChevron: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundColor(.secondary.opacity(0.75))
            Spacer()
            if hasChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var previewCustomItemsSection: some View {
        let enabled = viewModel.config.items.filter { $0.isEnabled }
        if enabled.isEmpty {
            Text(isTR ? "(Etkin öğe yok)" : "(No enabled items)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        } else if viewModel.config.foldAllIntoSingleMenu {
            previewFoldedGroup(
                title: viewModel.config.localizedNewMenuTitle,
                symbol: "plus.square.on.square",
                items: enabled
            )
        } else {
            let foldedNew = enabled.filter { $0.isFolded && $0.submenuGroup == .newMenu }
            let foldedQA = enabled.filter { $0.isFolded && $0.submenuGroup == .quickActions }
            let unfolded = enabled.filter { !$0.isFolded }

            if !foldedNew.isEmpty {
                previewFoldedGroup(
                    title: viewModel.config.localizedNewMenuTitle,
                    symbol: "doc.badge.plus",
                    items: foldedNew
                )
            }
            if !foldedQA.isEmpty {
                previewFoldedGroup(
                    title: viewModel.config.localizedQuickActionsTitle,
                    symbol: "bolt.circle",
                    items: foldedQA
                )
            }
            ForEach(unfolded) { item in
                previewLeafRow(item: item, indented: false)
            }
        }
    }

    private func previewFoldedGroup(title: String, symbol: String, items: [ContextMenuItem]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                if let subIcon = viewModel.config.submenuIconColor.renderedSymbolImage(name: symbol) {
                    Image(nsImage: subIcon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 15, height: 15)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(nsColor: viewModel.config.submenuIconColor.nsColor))
                        .frame(width: 16)
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(isTR ? "üzerine gelince açılır" : "hover")
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.8))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor))

            // Expanded submenu card preview
            VStack(alignment: .leading, spacing: 2) {
                ForEach(items) { item in
                    previewLeafRow(item: item, indented: true)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .padding(.leading, 18)
            .padding(.vertical, 2)
        }
    }

    private func previewLeafRow(item: ContextMenuItem, indented: Bool) -> some View {
        Button(action: {
            // Clicking an item in the live preview also lets you test it immediately in Finder's active directory!
            let targetDir = FinderSelectionHelper.currentFinderDirectoryPath()
            ActionExecutor.shared.execute(item: item, targetDirectoryPath: targetDir, config: viewModel.config)
            viewModel.showFlash(isTR ? "Çalıştırıldı: \(item.localizedTitle(isTR: true))" : "Executed: \(item.localizedTitle(isTR: false))")
        }) {
            HStack(spacing: 8) {
                if let nsImg = item.resolvedIcon() {
                    Image(nsImage: nsImg)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 15, height: 15)
                } else {
                    Image(systemName: item.iconSymbol)
                        .font(.system(size: 12))
                        .frame(width: 15, height: 15)
                }
                Text(item.localizedTitle(isTR: isTR))
                    .font(.system(size: 12.5))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isTR ? "Test etmek için tıklayın (aktif Finder klasöründe çalıştırır)" : "Click to test in the active Finder folder")
    }
}

struct MenuItemRowView: View {
    let item: ContextMenuItem
    let index: Int
    let totalCount: Int
    let isTR: Bool
    let newMenuLabel: String
    let quickActionsLabel: String
    let onToggleEnabled: (Bool) -> Void
    let onToggleFolded: (Bool) -> Void
    let onSelectColor: (IconColorOption) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { onToggleEnabled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()

            if let icon = item.resolvedIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: item.iconSymbol)
                    .font(.system(size: 16))
                    .foregroundColor(Color(nsColor: item.iconColor.nsColor))
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.localizedTitle(isTR: isTR))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(item.isEnabled ? .primary : .secondary)

                HStack(spacing: 6) {
                    Text(item.actionKind.label(isTR: isTR))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if item.actionKind == .createFile {
                        Text("• .\(item.fileExtension)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
            }

            Spacer()

            // Per-item icon color picker menu
            Menu {
                ForEach(IconColorOption.allCases) { opt in
                    Button(action: { onSelectColor(opt) }) {
                        Text(opt.label(isTR: isTR))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(nsColor: item.iconColor.nsColor))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
            .help(isTR ? "İkon rengini değiştir" : "Change icon color")

            // Foldable checkbox right on each item row!
            Toggle(isOn: Binding(
                get: { item.isFolded },
                set: { onToggleFolded($0) }
            )) {
                HStack(spacing: 4) {
                    Image(systemName: item.isFolded ? "folder.fill" : "list.bullet")
                        .font(.system(size: 10))
                    Text(item.isFolded
                         ? (item.submenuGroup == .newMenu ? newMenuLabel : quickActionsLabel)
                         : (isTR ? "Ana Menüde" : "Top Level"))
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .toggleStyle(.checkbox)
            .help(isTR
                  ? "İşaretlendiğinde öğe katlanabilir alt menü içine alınır (üzerine gelince açılır)."
                  : "When checked, this item is folded inside a hoverable submenu.")

            // Reorder & Edit buttons
            HStack(spacing: 4) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(index >= totalCount - 1)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

final class ItemEditorViewModel: ObservableObject {
    @Published var item: ContextMenuItem

    init(item: ContextMenuItem) {
        self.item = item
    }
}

struct ItemEditorSheet: View {
    @ObservedObject var editorModel: ItemEditorViewModel
    let isTR: Bool
    let onSave: (ContextMenuItem) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isTR ? "Menü Öğesini Düzenle" : "Edit Context Menu Item")
                .font(.system(size: 16, weight: .bold))

            Divider()

            Form {
                Section {
                    TextField(isTR ? "Başlık (İngilizce):" : "Title (English):", text: $editorModel.item.titleEN)
                    TextField(isTR ? "Başlık (Türkçe):" : "Title (Turkish):", text: $editorModel.item.titleTR)

                    Picker(isTR ? "İşlem Türü:" : "Action Type:", selection: $editorModel.item.actionKind) {
                        ForEach(ActionKind.allCases) { kind in
                            Text(kind.label(isTR: isTR)).tag(kind)
                        }
                    }

                    Toggle(
                        isTR ? "Alt menü içinde katla (üzerine gelince açılır)" : "Fold into hoverable submenu",
                        isOn: $editorModel.item.isFolded
                    )

                    if editorModel.item.isFolded {
                        Picker(isTR ? "Hangi Alt Menüde:" : "Submenu Group:", selection: $editorModel.item.submenuGroup) {
                            ForEach(SubmenuGroup.allCases) { group in
                                Text(group.label(isTR: isTR)).tag(group)
                            }
                        }
                    }
                }

                if editorModel.item.actionKind == .createFile {
                    Section {
                        TextField(isTR ? "Dosya Uzantısı (ör. txt, pages, key, docx):" : "File Extension (e.g. txt, pages, key, docx):", text: $editorModel.item.fileExtension)
                        TextField(isTR ? "Varsayılan Dosya Adı (EN):" : "Default Filename (EN):", text: $editorModel.item.baseFileNameEN)
                        TextField(isTR ? "Varsayılan Dosya Adı (TR):" : "Default Filename (TR):", text: $editorModel.item.baseFileNameTR)

                        Picker(isTR ? "Şablon Türü:" : "Document Template:", selection: $editorModel.item.templateKind) {
                            ForEach(TemplateKind.allCases) { tk in
                                Text(tk.label(isTR: isTR)).tag(tk)
                            }
                        }

                        if editorModel.item.templateKind == .customText {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isTR ? "Başlangıç Metin İçeriği:" : "Initial Text Content:")
                                    .font(.system(size: 12))
                                TextEditor(text: $editorModel.item.customInitialText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(height: 80)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                            }
                        } else if editorModel.item.templateKind == .customFile {
                            HStack {
                                TextField(isTR ? "Şablon Dosya Yolu:" : "Template File Path:", text: $editorModel.item.customTemplatePath)
                                Button(isTR ? "Dosya Seç..." : "Choose...") {
                                    let panel = NSOpenPanel()
                                    panel.canChooseFiles = true
                                    panel.canChooseDirectories = false
                                    panel.allowsMultipleSelection = false
                                    if panel.runModal() == .OK, let url = panel.url {
                                        editorModel.item.customTemplatePath = url.path
                                        if !url.pathExtension.isEmpty {
                                            editorModel.item.fileExtension = url.pathExtension
                                        }
                                    }
                                }
                            }
                        }

                        Toggle(
                            isTR ? "macOS sistem dosya simgesini kullan" : "Use native macOS file type icon",
                            isOn: $editorModel.item.useSystemFileIcon
                        )

                        Toggle(
                            isTR ? "Oluşturulduktan sonra dosyayı varsayılan uygulamada aç" : "Open file immediately after creating it",
                            isOn: $editorModel.item.openAfterCreation
                        )
                    }
                } else if editorModel.item.actionKind == .customCommand {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(isTR ? "Çalıştırılacak Shell Komutu ($CONTEXT_DIR = sağ tıklanan klasör):" : "Shell Command ($CONTEXT_DIR = right-clicked folder):")
                                .font(.system(size: 12))
                            TextField("open -a 'Visual Studio Code' \"$CONTEXT_DIR\"", text: $editorModel.item.customShellCommand)
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                }

                if !editorModel.item.useSystemFileIcon || editorModel.item.actionKind != .createFile {
                    Section {
                        TextField(isTR ? "SF Symbol İkon Adı (ör. doc.text, terminal):" : "SF Symbol Name (e.g. doc.text, terminal):", text: $editorModel.item.iconSymbol)
                        Picker(isTR ? "İkon Rengi:" : "Icon Color:", selection: $editorModel.item.iconColor) {
                            ForEach(IconColorOption.allCases) { opt in
                                Text(opt.label(isTR: isTR)).tag(opt)
                            }
                        }
                    }
                } else {
                    Section {
                        Picker(isTR ? "Sembol İkon Rengi:" : "Symbol Icon Color:", selection: $editorModel.item.iconColor) {
                            ForEach(IconColorOption.allCases) { opt in
                                Text(opt.label(isTR: isTR)).tag(opt)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(isTR ? "İptal" : "Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(isTR ? "Kaydet" : "Save") {
                    onSave(editorModel.item)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 500)
    }
}

struct ThirdPartyEntryRowView: View {
    let entry: ThirdPartyMenuEntry
    let isTR: Bool
    let onToggle: (Bool) -> Void
    let onRevealInFinder: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: entry.appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.entryTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(entry.isEnabled ? .primary : .secondary)

                    Text(entry.isEnabled
                         ? (isTR ? "Görünür" : "Visible")
                         : (isTR ? "Gizli" : "Hidden"))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(entry.isEnabled ? Color.green.opacity(0.18) : Color.secondary.opacity(0.16))
                        )
                        .foregroundColor(entry.isEnabled ? .green : .secondary)
                }

                Text("\(entry.appName) • \(entry.bundleIdentifier)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onRevealInFinder) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help(isTR ? "Finder'da Göster" : "Reveal in Finder")

            Toggle("", isOn: Binding(
                get: { entry.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
