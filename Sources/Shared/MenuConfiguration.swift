import Foundation
import AppKit
import UniformTypeIdentifiers

public enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case turkish = "tr"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System Default (Otomatik)"
        case .english: return "English"
        case .turkish: return "Türkçe"
        }
    }

    public var resolvedIsTurkish: Bool {
        switch self {
        case .english:
            return false
        case .turkish:
            return true
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("tr")
        }
    }
}

public enum IconColorOption: String, Codable, CaseIterable, Identifiable {
    case white = "white"
    case lightGray = "lightGray"
    case skyBlue = "skyBlue"
    case cyan = "cyan"
    case green = "green"
    case yellow = "yellow"
    case orange = "orange"
    case pink = "pink"
    case purple = "purple"
    case red = "red"
    case charcoal = "charcoal"

    public var id: String { rawValue }

    public func label(isTR: Bool) -> String {
        switch self {
        case .white: return isTR ? "Beyaz (Koyu Mod İçin Önerilen)" : "White (Best for Dark Mode)"
        case .lightGray: return isTR ? "Açık Gri / Gümüş" : "Light Silver"
        case .skyBlue: return isTR ? "Mavi" : "Blue"
        case .cyan: return isTR ? "Turkuaz / Camgöbeği" : "Cyan"
        case .green: return isTR ? "Yeşil" : "Green"
        case .yellow: return isTR ? "Sarı" : "Yellow"
        case .orange: return isTR ? "Turuncu" : "Orange"
        case .pink: return isTR ? "Pembe" : "Pink"
        case .purple: return isTR ? "Mor" : "Purple"
        case .red: return isTR ? "Kırmızı" : "Red"
        case .charcoal: return isTR ? "Koyu Gri / Siyah (Açık Mod)" : "Dark Charcoal (Light Mode)"
        }
    }

    public var nsColor: NSColor {
        switch self {
        case .white:
            return NSColor(srgbRed: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
        case .lightGray:
            return NSColor(srgbRed: 0.78, green: 0.81, blue: 0.86, alpha: 1.0)
        case .skyBlue:
            return NSColor(srgbRed: 0.30, green: 0.62, blue: 1.00, alpha: 1.0)
        case .cyan:
            return NSColor(srgbRed: 0.15, green: 0.82, blue: 0.92, alpha: 1.0)
        case .green:
            return NSColor(srgbRed: 0.24, green: 0.84, blue: 0.50, alpha: 1.0)
        case .yellow:
            return NSColor(srgbRed: 0.98, green: 0.80, blue: 0.18, alpha: 1.0)
        case .orange:
            return NSColor(srgbRed: 1.00, green: 0.56, blue: 0.20, alpha: 1.0)
        case .pink:
            return NSColor(srgbRed: 0.96, green: 0.42, blue: 0.71, alpha: 1.0)
        case .purple:
            return NSColor(srgbRed: 0.72, green: 0.48, blue: 0.98, alpha: 1.0)
        case .red:
            return NSColor(srgbRed: 0.97, green: 0.38, blue: 0.38, alpha: 1.0)
        case .charcoal:
            return NSColor(srgbRed: 0.18, green: 0.20, blue: 0.24, alpha: 1.0)
        }
    }

    /// Renders an SF Symbol into an explicit @2x Retina bitmap tinted with this color so Finder's XPC menu proxy preserves the exact color in Dark Mode and Light Mode.
    public func renderedSymbolImage(name: String, pointSize: CGFloat = 13.5) -> NSImage? {
        guard let baseSymbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
            .applying(NSImage.SymbolConfiguration.preferringMonochrome())
        let configured = baseSymbol.withSymbolConfiguration(symbolConfig) ?? baseSymbol

        let targetSize = NSSize(width: 16, height: 16)
        let pixelWidth = 32
        let pixelHeight = 32

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return configured
        }
        rep.size = targetSize

        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            ctx.imageInterpolation = .high

            let symSize = configured.size
            let drawRect = NSRect(
                x: (targetSize.width - symSize.width) / 2.0,
                y: (targetSize.height - symSize.height) / 2.0,
                width: symSize.width,
                height: symSize.height
            )
            configured.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

            // Tint all drawn alpha pixels with exact `nsColor`
            nsColor.setFill()
            NSRect(origin: .zero, size: targetSize).fill(using: .sourceAtop)
        }
        NSGraphicsContext.restoreGraphicsState()

        let finalImage = NSImage(size: targetSize)
        finalImage.addRepresentation(rep)
        finalImage.isTemplate = false
        return finalImage
    }
}

public enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case createFile = "createFile"
    case openTerminal = "openTerminal"
    case openWithApp = "openWithApp"
    case copyPath = "copyPath"
    case customCommand = "customCommand"

    public var id: String { rawValue }

    public func label(isTR: Bool) -> String {
        switch self {
        case .createFile:
            return isTR ? "Yeni Dosya Oluştur" : "Create New File"
        case .openTerminal:
            return isTR ? "Burada Terminal Aç" : "Open Terminal Here"
        case .openWithApp:
            return isTR ? "Uygulama ile Aç (Antigravity, Zed, VS Code vb.)" : "Open Folder with Application"
        case .copyPath:
            return isTR ? "Klasör Yolunu Kopyala" : "Copy Folder Path"
        case .customCommand:
            return isTR ? "Özel Kabuk Komutu (Shell)" : "Custom Shell Command"
        }
    }
}

public enum TemplateKind: String, Codable, CaseIterable, Identifiable {
    case plainText = "plainText"
    case pagesBlank = "pagesBlank"
    case keynoteBlank = "keynoteBlank"
    case numbersBlank = "numbersBlank"
    case docxBlank = "docxBlank"
    case customText = "customText"
    case customFile = "customFile"

    public var id: String { rawValue }

    public func label(isTR: Bool) -> String {
        switch self {
        case .plainText:
            return isTR ? "Boş Metin Dosyası (.txt / UTF-8)" : "Empty Text File (.txt / UTF-8)"
        case .pagesBlank:
            return isTR ? "Apple Pages Boş Belge (.pages)" : "Apple Pages Blank Document (.pages)"
        case .keynoteBlank:
            return isTR ? "Apple Keynote Boş Sunum (.key)" : "Apple Keynote Blank Presentation (.key)"
        case .numbersBlank:
            return isTR ? "Apple Numbers Boş Tablo (.numbers)" : "Apple Numbers Blank Spreadsheet (.numbers)"
        case .docxBlank:
            return isTR ? "Microsoft Word Boş Belge (.docx)" : "Microsoft Word Blank Document (.docx)"
        case .customText:
            return isTR ? "Özel Metin Şablonu" : "Custom Text Content"
        case .customFile:
            return isTR ? "Özel Şablon Dosyası" : "Custom Template File"
        }
    }
}

public enum SubmenuGroup: String, Codable, CaseIterable, Identifiable {
    case newMenu = "newMenu"
    case quickActions = "quickActions"

    public var id: String { rawValue }

    public func label(isTR: Bool) -> String {
        switch self {
        case .newMenu:
            return isTR ? "\"Yeni...\" Alt Menüsü" : "\"New...\" Submenu"
        case .quickActions:
            return isTR ? "\"Hızlı İşlemler\" Alt Menüsü" : "\"Quick Actions\" Submenu"
        }
    }
}

public struct ContextMenuItem: Codable, Identifiable, Equatable {
    public var id: UUID
    public var titleEN: String
    public var titleTR: String
    public var iconSymbol: String
    public var iconColor: IconColorOption
    public var useSystemFileIcon: Bool
    /// Optional path to a `.app` bundle (e.g. `/Applications/Antigravity.app`) or custom `.png`/`.icns` icon file.
    public var customAppOrIconPath: String
    public var isEnabled: Bool
    /// When true, this item is folded inside a hoverable submenu (e.g. "New..." -> "Text File").
    /// When false, this item appears directly on the top-level right-click menu.
    public var isFolded: Bool
    public var submenuGroup: SubmenuGroup
    public var actionKind: ActionKind
    public var fileExtension: String
    public var baseFileNameEN: String
    public var baseFileNameTR: String
    public var templateKind: TemplateKind
    public var customTemplatePath: String
    public var customInitialText: String
    public var customShellCommand: String
    public var openAfterCreation: Bool

    public init(
        id: UUID = UUID(),
        titleEN: String,
        titleTR: String,
        iconSymbol: String = "doc.badge.plus",
        iconColor: IconColorOption = .white,
        useSystemFileIcon: Bool = true,
        customAppOrIconPath: String = "",
        isEnabled: Bool = true,
        isFolded: Bool = true,
        submenuGroup: SubmenuGroup = .newMenu,
        actionKind: ActionKind = .createFile,
        fileExtension: String = "txt",
        baseFileNameEN: String = "Untitled",
        baseFileNameTR: String = "Adsız",
        templateKind: TemplateKind = .plainText,
        customTemplatePath: String = "",
        customInitialText: String = "",
        customShellCommand: String = "",
        openAfterCreation: Bool = false
    ) {
        self.id = id
        self.titleEN = titleEN
        self.titleTR = titleTR
        self.iconSymbol = iconSymbol
        self.iconColor = iconColor
        self.useSystemFileIcon = useSystemFileIcon
        self.customAppOrIconPath = customAppOrIconPath
        self.isEnabled = isEnabled
        self.isFolded = isFolded
        self.submenuGroup = submenuGroup
        self.actionKind = actionKind
        self.fileExtension = fileExtension
        self.baseFileNameEN = baseFileNameEN
        self.baseFileNameTR = baseFileNameTR
        self.templateKind = templateKind
        self.customTemplatePath = customTemplatePath
        self.customInitialText = customInitialText
        self.customShellCommand = customShellCommand
        self.openAfterCreation = openAfterCreation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.titleEN = try c.decodeIfPresent(String.self, forKey: .titleEN) ?? "Item"
        self.titleTR = try c.decodeIfPresent(String.self, forKey: .titleTR) ?? self.titleEN
        self.iconSymbol = try c.decodeIfPresent(String.self, forKey: .iconSymbol) ?? "doc.badge.plus"
        self.iconColor = try c.decodeIfPresent(IconColorOption.self, forKey: .iconColor) ?? .white
        self.useSystemFileIcon = try c.decodeIfPresent(Bool.self, forKey: .useSystemFileIcon) ?? true
        self.customAppOrIconPath = try c.decodeIfPresent(String.self, forKey: .customAppOrIconPath) ?? ""
        self.isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.isFolded = try c.decodeIfPresent(Bool.self, forKey: .isFolded) ?? true
        self.submenuGroup = try c.decodeIfPresent(SubmenuGroup.self, forKey: .submenuGroup) ?? .newMenu
        self.actionKind = try c.decodeIfPresent(ActionKind.self, forKey: .actionKind) ?? .createFile
        self.fileExtension = try c.decodeIfPresent(String.self, forKey: .fileExtension) ?? "txt"
        self.baseFileNameEN = try c.decodeIfPresent(String.self, forKey: .baseFileNameEN) ?? "Untitled"
        self.baseFileNameTR = try c.decodeIfPresent(String.self, forKey: .baseFileNameTR) ?? "Adsız"
        self.templateKind = try c.decodeIfPresent(TemplateKind.self, forKey: .templateKind) ?? .plainText
        self.customTemplatePath = try c.decodeIfPresent(String.self, forKey: .customTemplatePath) ?? ""
        self.customInitialText = try c.decodeIfPresent(String.self, forKey: .customInitialText) ?? ""
        self.customShellCommand = try c.decodeIfPresent(String.self, forKey: .customShellCommand) ?? ""
        self.openAfterCreation = try c.decodeIfPresent(Bool.self, forKey: .openAfterCreation) ?? false
    }

    public func localizedTitle(isTR: Bool) -> String {
        let candidate = isTR ? titleTR : titleEN
        return candidate.isEmpty ? titleEN : candidate
    }

    public func localizedBaseFileName(isTR: Bool) -> String {
        let candidate = isTR ? baseFileNameTR : baseFileNameEN
        return candidate.isEmpty ? "Untitled" : candidate
    }

    public func resolvedIcon() -> NSImage? {
        if !customAppOrIconPath.isEmpty {
            let sourceIcon: NSImage?
            if customAppOrIconPath.hasSuffix(".app") || FileManager.default.fileExists(atPath: customAppOrIconPath) {
                if customAppOrIconPath.hasSuffix(".png") || customAppOrIconPath.hasSuffix(".icns") || customAppOrIconPath.hasSuffix(".jpg") {
                    sourceIcon = NSImage(contentsOfFile: customAppOrIconPath)
                } else {
                    sourceIcon = NSWorkspace.shared.icon(forFile: customAppOrIconPath)
                }
            } else {
                sourceIcon = nil
            }
            if let src = sourceIcon {
                return Self.rasterizeFullColorIcon(src, size: NSSize(width: 16, height: 16))
            }
        }
        if useSystemFileIcon && actionKind == .createFile && !fileExtension.isEmpty {
            let cleanExt = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if let utType = UTType(filenameExtension: cleanExt) {
                let icon = NSWorkspace.shared.icon(for: utType)
                icon.size = NSSize(width: 16, height: 16)
                return icon
            }
        }
        return iconColor.renderedSymbolImage(name: iconSymbol)
    }

    private static func rasterizeFullColorIcon(_ source: NSImage, size: NSSize) -> NSImage {
        let pixelW = Int(size.width * 2)
        let pixelH = Int(size.height * 2)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelW,
            pixelsHigh: pixelH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            source.size = size
            return source
        }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            ctx.imageInterpolation = .high
            source.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
        }
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: size)
        out.addRepresentation(rep)
        out.isTemplate = false
        return out
    }
}

public struct MenuConfiguration: Codable, Equatable {
    public var language: AppLanguage
    public var newMenuTitleEN: String
    public var newMenuTitleTR: String
    public var quickActionsTitleEN: String
    public var quickActionsTitleTR: String
    public var submenuIconColor: IconColorOption
    /// Optional master override to fold every enabled item into a single root submenu
    public var foldAllIntoSingleMenu: Bool
    public var showOnFolderBackground: Bool
    public var showOnSelectedFolders: Bool
    public var showOnSelectedFiles: Bool
    public var revealCreatedFileInFinder: Bool
    public var launchAtLoginHidden: Bool
    public var terminalAppBundleID: String
    public var monitoredDirectories: [String]
    public var items: [ContextMenuItem]

    public init(
        language: AppLanguage = .system,
        newMenuTitleEN: String = "New...",
        newMenuTitleTR: String = "Yeni...",
        quickActionsTitleEN: String = "Quick Actions",
        quickActionsTitleTR: String = "Hızlı İşlemler",
        submenuIconColor: IconColorOption = .white,
        foldAllIntoSingleMenu: Bool = false,
        showOnFolderBackground: Bool = true,
        showOnSelectedFolders: Bool = true,
        showOnSelectedFiles: Bool = true,
        revealCreatedFileInFinder: Bool = false,
        launchAtLoginHidden: Bool = false,
        terminalAppBundleID: String = "com.apple.Terminal",
        monitoredDirectories: [String] = MenuConfiguration.defaultMonitoredDirectories(),
        items: [ContextMenuItem] = MenuConfiguration.defaultItems()
    ) {
        self.language = language
        self.newMenuTitleEN = newMenuTitleEN
        self.newMenuTitleTR = newMenuTitleTR
        self.quickActionsTitleEN = quickActionsTitleEN
        self.quickActionsTitleTR = quickActionsTitleTR
        self.submenuIconColor = submenuIconColor
        self.foldAllIntoSingleMenu = foldAllIntoSingleMenu
        self.showOnFolderBackground = showOnFolderBackground
        self.showOnSelectedFolders = showOnSelectedFolders
        self.showOnSelectedFiles = showOnSelectedFiles
        self.revealCreatedFileInFinder = revealCreatedFileInFinder
        self.launchAtLoginHidden = launchAtLoginHidden
        self.terminalAppBundleID = terminalAppBundleID
        self.monitoredDirectories = monitoredDirectories
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case language
        case newMenuTitleEN
        case newMenuTitleTR
        case quickActionsTitleEN
        case quickActionsTitleTR
        case submenuIconColor
        case foldAllIntoSingleMenu
        case showOnFolderBackground
        case showOnSelectedFolders
        case showOnSelectedFiles
        case revealCreatedFileInFinder = "autoRevealInFinderWindow"
        case launchAtLoginHidden
        case terminalAppBundleID
        case monitoredDirectories
        case items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        self.newMenuTitleEN = try c.decodeIfPresent(String.self, forKey: .newMenuTitleEN) ?? "New..."
        self.newMenuTitleTR = try c.decodeIfPresent(String.self, forKey: .newMenuTitleTR) ?? "Yeni..."
        self.quickActionsTitleEN = try c.decodeIfPresent(String.self, forKey: .quickActionsTitleEN) ?? "Quick Actions"
        self.quickActionsTitleTR = try c.decodeIfPresent(String.self, forKey: .quickActionsTitleTR) ?? "Hızlı İşlemler"
        self.submenuIconColor = try c.decodeIfPresent(IconColorOption.self, forKey: .submenuIconColor) ?? .white
        self.foldAllIntoSingleMenu = try c.decodeIfPresent(Bool.self, forKey: .foldAllIntoSingleMenu) ?? false
        self.showOnFolderBackground = try c.decodeIfPresent(Bool.self, forKey: .showOnFolderBackground) ?? true
        self.showOnSelectedFolders = try c.decodeIfPresent(Bool.self, forKey: .showOnSelectedFolders) ?? true
        self.showOnSelectedFiles = try c.decodeIfPresent(Bool.self, forKey: .showOnSelectedFiles) ?? true
        self.revealCreatedFileInFinder = try c.decodeIfPresent(Bool.self, forKey: .revealCreatedFileInFinder) ?? false
        self.launchAtLoginHidden = try c.decodeIfPresent(Bool.self, forKey: .launchAtLoginHidden) ?? false
        self.terminalAppBundleID = try c.decodeIfPresent(String.self, forKey: .terminalAppBundleID) ?? "com.apple.Terminal"
        self.monitoredDirectories = try c.decodeIfPresent([String].self, forKey: .monitoredDirectories) ?? MenuConfiguration.defaultMonitoredDirectories()
        self.items = try c.decodeIfPresent([ContextMenuItem].self, forKey: .items) ?? MenuConfiguration.defaultItems()
    }

    public var isTurkish: Bool {
        language.resolvedIsTurkish
    }

    public var localizedNewMenuTitle: String {
        isTurkish ? (newMenuTitleTR.isEmpty ? "Yeni..." : newMenuTitleTR) : (newMenuTitleEN.isEmpty ? "New..." : newMenuTitleEN)
    }

    public var localizedQuickActionsTitle: String {
        isTurkish ? (quickActionsTitleTR.isEmpty ? "Hızlı İşlemler" : quickActionsTitleTR) : (quickActionsTitleEN.isEmpty ? "Quick Actions" : quickActionsTitleEN)
    }

    public static func defaultMonitoredDirectories() -> [String] {
        return ["/"]
    }

    public static func defaultItems() -> [ContextMenuItem] {
        return [
            ContextMenuItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                titleEN: "Text File (.txt)",
                titleTR: "Metin Belgesi (.txt)",
                iconSymbol: "doc.text",
                iconColor: .white,
                useSystemFileIcon: true,
                isEnabled: true,
                isFolded: true,
                submenuGroup: .newMenu,
                actionKind: .createFile,
                fileExtension: "txt",
                baseFileNameEN: "Untitled",
                baseFileNameTR: "Adsız",
                templateKind: .plainText
            ),
            ContextMenuItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                titleEN: "Pages Document (.pages)",
                titleTR: "Pages Belgesi (.pages)",
                iconSymbol: "doc.richtext",
                iconColor: .orange,
                useSystemFileIcon: true,
                isEnabled: true,
                isFolded: true,
                submenuGroup: .newMenu,
                actionKind: .createFile,
                fileExtension: "pages",
                baseFileNameEN: "Untitled",
                baseFileNameTR: "Adsız",
                templateKind: .pagesBlank
            ),
            ContextMenuItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                titleEN: "Keynote Presentation (.key)",
                titleTR: "Keynote Sunusu (.key)",
                iconSymbol: "play.rectangle",
                iconColor: .skyBlue,
                useSystemFileIcon: true,
                isEnabled: true,
                isFolded: true,
                submenuGroup: .newMenu,
                actionKind: .createFile,
                fileExtension: "key",
                baseFileNameEN: "Untitled",
                baseFileNameTR: "Adsız",
                templateKind: .keynoteBlank
            ),
            ContextMenuItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                titleEN: "Numbers Spreadsheet (.numbers)",
                titleTR: "Numbers Hesap Tablosu (.numbers)",
                iconSymbol: "tablecells",
                iconColor: .green,
                useSystemFileIcon: true,
                isEnabled: true,
                isFolded: true,
                submenuGroup: .newMenu,
                actionKind: .createFile,
                fileExtension: "numbers",
                baseFileNameEN: "Untitled",
                baseFileNameTR: "Adsız",
                templateKind: .numbersBlank
            ),
            ContextMenuItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
                titleEN: "Word Document (.docx)",
                titleTR: "Word Belgesi (.docx)",
                iconSymbol: "doc.fill",
                iconColor: .skyBlue,
                useSystemFileIcon: true,
                isEnabled: true,
                isFolded: true,
                submenuGroup: .newMenu,
                actionKind: .createFile,
                fileExtension: "docx",
                baseFileNameEN: "Untitled",
                baseFileNameTR: "Adsız",
                templateKind: .docxBlank
            ),
            ContextMenuItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
                titleEN: "Markdown File (.md)",
                titleTR: "Markdown Dosyası (.md)",
                iconSymbol: "text.badge.plus",
                iconColor: .cyan,
                useSystemFileIcon: false,
                isEnabled: false,
                isFolded: true,
                submenuGroup: .newMenu,
                actionKind: .createFile,
                fileExtension: "md",
                baseFileNameEN: "Untitled",
                baseFileNameTR: "Adsız",
                templateKind: .customText,
                customInitialText: "# Untitled\n\n"
            ),
            ContextMenuItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
                titleEN: "Open Terminal Here",
                titleTR: "Burada Terminal Aç",
                iconSymbol: "terminal",
                iconColor: .white,
                useSystemFileIcon: false,
                isEnabled: true,
                isFolded: false,
                submenuGroup: .quickActions,
                actionKind: .openTerminal
            ),
            ContextMenuItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
                titleEN: "Copy Folder Path",
                titleTR: "Klasör Yolunu Kopyala",
                iconSymbol: "doc.on.doc",
                iconColor: .white,
                useSystemFileIcon: false,
                isEnabled: true,
                isFolded: false,
                submenuGroup: .quickActions,
                actionKind: .copyPath
            )
        ]
    }
}

public enum ConfigConstants {
    public static let appBundleID = "com.contextmenustudio.app"
    public static let extensionBundleID = "com.contextmenustudio.app.FinderSync"
    public static let configUpdatedNotification = Notification.Name("com.contextmenustudio.configUpdated")
    public static let executeActionNotification = Notification.Name("com.contextmenustudio.executeAction")
    public static let requestConfigNotification = Notification.Name("com.contextmenustudio.requestConfig")
    public static let urlScheme = "contextmenustudio"
}

public struct ActionExecutionPayload: Codable {
    public let itemID: UUID
    public let targetDirectoryPath: String
    public let selectedPaths: [String]

    public init(itemID: UUID, targetDirectoryPath: String, selectedPaths: [String] = []) {
        self.itemID = itemID
        self.targetDirectoryPath = targetDirectoryPath
        self.selectedPaths = selectedPaths
    }
}

public final class ConfigStore {
    public static let shared = ConfigStore()

    private init() {}

    /// Real user home directory (even when called from inside a sandboxed extension)
    public var realUserHomePath: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }

    public var primaryConfigFileURL: URL {
        let base = URL(fileURLWithPath: realUserHomePath)
            .appendingPathComponent("Library/Application Support/ContextMenuStudio", isDirectory: true)
        return base.appendingPathComponent("config.json")
    }

    public var extensionContainerConfigFileURL: URL {
        let base = URL(fileURLWithPath: realUserHomePath)
            .appendingPathComponent("Library/Containers/\(ConfigConstants.extensionBundleID)/Data/Library/Application Support/ContextMenuStudio", isDirectory: true)
        return base.appendingPathComponent("config.json")
    }

    public var localProcessConfigFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("ContextMenuStudio", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    public func load() -> MenuConfiguration {
        let candidateURLs = [
            localProcessConfigFileURL,
            primaryConfigFileURL,
            extensionContainerConfigFileURL,
            URL(fileURLWithPath: "/tmp/ContextMenuStudio_config.json")
        ]

        let decoder = JSONDecoder()
        for url in candidateURLs {
            if let data = try? Data(contentsOf: url),
               let config = try? decoder.decode(MenuConfiguration.self, from: data) {
                return config
            }
        }
        return MenuConfiguration()
    }

    public func save(_ config: MenuConfiguration, broadcast: Bool = true) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }

        let targetURLs = [
            primaryConfigFileURL,
            extensionContainerConfigFileURL,
            localProcessConfigFileURL,
            URL(fileURLWithPath: "/tmp/ContextMenuStudio_config.json")
        ]

        for url in targetURLs {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }

        if broadcast, let jsonString = String(data: data, encoding: .utf8) {
            DistributedNotificationCenter.default().postNotificationName(
                ConfigConstants.configUpdatedNotification,
                object: jsonString,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }
}
