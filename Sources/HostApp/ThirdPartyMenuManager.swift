import Foundation
import AppKit

public enum ThirdPartyExtensionCategory: String, CaseIterable, Identifiable {
    case finderSync = "finderSync"
    case quickActionsAndShare = "quickActionsAndShare"
    case systemServices = "systemServices"

    public var id: String { rawValue }

    public func title(isTR: Bool) -> String {
        switch self {
        case .finderSync:
            return isTR
                ? "Finder Sağ Tık Menüsü Uzantıları (FinderSync & Bulut)"
                : "Finder Context Menu Extensions (FinderSync & Cloud)"
        case .quickActionsAndShare:
            return isTR
                ? "Hızlı Eylemler ve Paylaşım Uzantıları"
                : "Quick Actions & Share Menu Extensions"
        case .systemServices:
            return isTR
                ? "Uygulama Sağ Tık Servisleri (NSServices)"
                : "Application Context Menu Services (NSServices)"
        }
    }

    public func subtitle(isTR: Bool) -> String {
        switch self {
        case .finderSync:
            return isTR
                ? "Gemini, Keka, Google Drive gibi klasör arka planına ve dosyalara doğrudan sağ tık seçeneği ekleyen uygulamalar."
                : "Apps like Gemini, Keka, and Google Drive that add items directly to folder backgrounds and files."
        case .quickActionsAndShare:
            return isTR
                ? "Sağ tık Hızlı Eylemler (Quick Actions) ve Paylaş (Share) alt menülerinde görünen uzantılar."
                : "Extensions shown inside Finder's Quick Actions and Share submenus."
        case .systemServices:
            return isTR
                ? "En alttaki 'Servisler / Hızlı Eylemler' menüsüne öğe ekleyen uygulama servisleri."
                : "App services shown under the Services / Quick Actions section of the context menu."
        }
    }
}

public struct ThirdPartyMenuEntry: Identifiable, Equatable {
    public let id: String
    public let appName: String
    public let entryTitle: String
    public let bundleIdentifier: String
    public let extensionPointIdentifier: String
    public let appBundlePath: String
    public let pluginPath: String
    public let category: ThirdPartyExtensionCategory
    public var isEnabled: Bool
    public let serviceKey: String?

    public var appIcon: NSImage {
        let icon = NSWorkspace.shared.icon(forFile: appBundlePath)
        icon.size = NSSize(width: 28, height: 28)
        return icon
    }

    public static func == (lhs: ThirdPartyMenuEntry, rhs: ThirdPartyMenuEntry) -> Bool {
        lhs.id == rhs.id && lhs.isEnabled == rhs.isEnabled
    }
}

@MainActor
public final class ThirdPartyMenuManager: ObservableObject {
    public static let shared = ThirdPartyMenuManager()

    @Published public var entries: [ThirdPartyMenuEntry] = []
    @Published public var isScanning: Bool = false
    @Published public var searchQuery: String = ""

    private let stateOverridesKey = "ContextMenuStudio.ThirdPartyOverrides"

    private init() {}

    public func refreshEntries() {
        isScanning = true
        Task.detached(priority: .userInitiated) {
            let discovered = Self.discoverAllEntries()
            await MainActor.run {
                self.entries = discovered
                self.isScanning = false
            }
        }
    }

    public func toggleEntry(_ entry: ThirdPartyMenuEntry, enabled: Bool) -> Bool {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx].isEnabled = enabled
        }

        // Persist user's choice locally as well so UI state is always consistent
        var overrides = UserDefaults.standard.dictionary(forKey: stateOverridesKey) as? [String: Bool] ?? [:]
        overrides[entry.id] = enabled
        UserDefaults.standard.set(overrides, forKey: stateOverridesKey)

        let entryCopy = entry
        Task.detached(priority: .userInitiated) {
            if entryCopy.category == .systemServices, let serviceKey = entryCopy.serviceKey {
                Self.setSystemServiceEnabled(serviceKey: serviceKey, enabled: enabled)
            } else {
                Self.setPluginKitEnabled(
                    bundleID: entryCopy.bundleIdentifier,
                    pluginPath: entryCopy.pluginPath,
                    enabled: enabled
                )
            }
        }
        return true
    }

    public func restartFinder() {
        Task.detached(priority: .userInitiated) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            task.arguments = ["Finder"]
            try? task.run()
            task.waitUntilExit()
        }
    }

    // MARK: - Discovery & Control Implementation

    nonisolated private static func discoverAllEntries() -> [ThirdPartyMenuEntry] {
        var results: [ThirdPartyMenuEntry] = []
        let overrides = UserDefaults.standard.dictionary(forKey: "ContextMenuStudio.ThirdPartyOverrides") as? [String: Bool] ?? [:]

        // 1. Query pluginkit states if available
        let pluginkitStates = queryAllPluginKitElections()

        // 2. Scan /Applications and ~/Applications for .app bundles
        var appDirectories = ["/Applications"]
        let userApps = (ConfigStore.shared.realUserHomePath as NSString).appendingPathComponent("Applications")
        if FileManager.default.fileExists(atPath: userApps) {
            appDirectories.append(userApps)
        }

        var seenBundleIDs = Set<String>()

        for appDir in appDirectories {
            guard let topApps = try? FileManager.default.contentsOfDirectory(atPath: appDir) else { continue }
            for item in topApps where item.hasSuffix(".app") {
                let topAppPath = (appDir as NSString).appendingPathComponent(item)
                let appDisplayName = ((item as NSString).deletingPathExtension)

                // Find all .appex bundles inside this .app (including nested helper apps like Google Drive's FinderHelper.app)
                let appexPaths = findAppexBundles(inside: topAppPath, maxDepth: 5)
                for appexPath in appexPaths {
                    let infoPlistPath = (appexPath as NSString).appendingPathComponent("Contents/Info.plist")
                    guard let plist = NSDictionary(contentsOfFile: infoPlistPath),
                          let bundleID = plist["CFBundleIdentifier"] as? String,
                          !seenBundleIDs.contains(bundleID) else {
                        continue
                    }

                    // Skip our own extension in the "Other Apps" list (or keep it clearly labeled)
                    if bundleID == ConfigConstants.extensionBundleID {
                        continue
                    }

                    let extDict = plist["NSExtension"] as? NSDictionary
                    let extPoint = (extDict?["NSExtensionPointIdentifier"] as? String) ?? ""

                    let category: ThirdPartyExtensionCategory?
                    switch extPoint {
                    case "com.apple.FinderSync", "com.apple.fileprovider-nonui":
                        category = .finderSync
                    case "com.apple.ui-services", "com.apple.share-services", "com.apple.services":
                        category = .quickActionsAndShare
                    default:
                        category = nil
                    }

                    guard let resolvedCategory = category else { continue }
                    seenBundleIDs.insert(bundleID)

                    let displayName = (plist["CFBundleDisplayName"] as? String)
                        ?? (plist["CFBundleName"] as? String)
                        ?? ((appexPath as NSString).lastPathComponent as NSString).deletingPathExtension

                    // Determine enabled state:
                    // 1) pluginkit election if reported (`+` = true, `-` = false)
                    // 2) user override
                    // 3) default true for installed FinderSync/Action extensions
                    let isEnabled: Bool
                    if let pkState = pluginkitStates[bundleID] {
                        isEnabled = pkState
                    } else if let singleState = querySinglePluginKitState(bundleID: bundleID) {
                        isEnabled = singleState
                    } else if let override = overrides[bundleID] {
                        isEnabled = override
                    } else {
                        isEnabled = true
                    }

                    results.append(ThirdPartyMenuEntry(
                        id: bundleID,
                        appName: appDisplayName,
                        entryTitle: friendlyContextMenuLabel(forApp: appDisplayName, displayName: displayName, extPoint: extPoint),
                        bundleIdentifier: bundleID,
                        extensionPointIdentifier: extPoint,
                        appBundlePath: topAppPath,
                        pluginPath: appexPath,
                        category: resolvedCategory,
                        isEnabled: isEnabled,
                        serviceKey: nil
                    ))
                }

                // 3. Also check if this .app declares NSServices in its Info.plist
                let appInfoPlistPath = (topAppPath as NSString).appendingPathComponent("Contents/Info.plist")
                if let appPlist = NSDictionary(contentsOfFile: appInfoPlistPath),
                   let appBundleID = appPlist["CFBundleIdentifier"] as? String,
                   let services = appPlist["NSServices"] as? [NSDictionary] {
                    let pbsStatus = readPBSServicesStatus()
                    for service in services {
                        guard let menuItemDict = service["NSMenuItem"] as? NSDictionary,
                              let menuTitle = menuItemDict["default"] as? String,
                              let message = service["NSMessage"] as? String else {
                            continue
                        }
                        let serviceKey = "\(appBundleID) - \(menuTitle) - \(message)"
                        let entryID = "service:\(serviceKey)"
                        guard !seenBundleIDs.contains(entryID) else { continue }
                        seenBundleIDs.insert(entryID)

                        let isEnabled: Bool
                        if let st = pbsStatus[serviceKey] {
                            isEnabled = st
                        } else if let override = overrides[entryID] {
                            isEnabled = override
                        } else {
                            isEnabled = true
                        }

                        results.append(ThirdPartyMenuEntry(
                            id: entryID,
                            appName: appDisplayName,
                            entryTitle: menuTitle,
                            bundleIdentifier: appBundleID,
                            extensionPointIdentifier: "NSServices",
                            appBundlePath: topAppPath,
                            pluginPath: topAppPath,
                            category: .systemServices,
                            isEnabled: isEnabled,
                            serviceKey: serviceKey
                        ))
                    }
                }
            }
        }

        return results.sorted { a, b in
            if a.category != b.category {
                return a.category.rawValue < b.category.rawValue
            }
            return a.appName.localizedCaseInsensitiveCompare(b.appName) == .orderedAscending
        }
    }

    nonisolated private static func friendlyContextMenuLabel(forApp appName: String, displayName: String, extPoint: String) -> String {
        let lowerApp = appName.lowercased()
        if lowerApp.contains("gemini") {
            return "Gemini (\"Gemini'a ekle\" / \"Add to Gemini\")"
        } else if lowerApp.contains("keka") {
            return "Keka (\"Keka ile sıkıştır\" / \"Compress with Keka\")"
        } else if lowerApp.contains("google drive") {
            if extPoint == "com.apple.FinderSync" {
                return "Google Drive (\"Bu klasörü Senkronize Et veya Yedekle\")"
            } else {
                return "Google Drive File Provider"
            }
        }
        return "\(appName) — \(displayName)"
    }

    nonisolated private static func findAppexBundles(inside rootPath: String, maxDepth: Int) -> [String] {
        var found: [String] = []
        let fm = FileManager.default
        let rootComponentsCount = (rootPath as NSString).pathComponents.count

        guard let enumerator = fm.enumerator(atPath: rootPath) else { return [] }
        while let relPath = enumerator.nextObject() as? String {
            let fullPath = (rootPath as NSString).appendingPathComponent(relPath)
            let depth = (fullPath as NSString).pathComponents.count - rootComponentsCount
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }
            if relPath.hasSuffix(".appex") {
                found.append(fullPath)
                enumerator.skipDescendants()
            }
        }
        return found
    }

    nonisolated private static func queryAllPluginKitElections() -> [String: Bool] {
        guard let output = runCommandOutput("/usr/bin/pluginkit", arguments: ["-m"]) else {
            return [:]
        }
        var map: [String: Bool] = [:]
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // pluginkit -m lines look like: "+    com.aone.keka.KekaFinderIntegration(1.6.8)" or "-    com.google.GeminiMacOS.FinderSync(1.119.02.0)"
            let firstChar = line.first ?? " "
            let isExplicitDisabled = (firstChar == "-")
            if let parenIndex = trimmed.firstIndex(of: "(") {
                let prefix = trimmed[..<parenIndex]
                let parts = prefix.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let bundleID = parts.last {
                    map[bundleID] = !isExplicitDisabled
                }
            }
        }
        return map
    }

    nonisolated private static func querySinglePluginKitState(bundleID: String) -> Bool? {
        guard let output = runCommandOutput("/usr/bin/pluginkit", arguments: ["-m", "-i", bundleID]) else {
            return nil
        }
        for line in output.components(separatedBy: .newlines) {
            if line.contains(bundleID) {
                let firstChar = line.first ?? " "
                return firstChar != "-"
            }
        }
        return nil
    }

    nonisolated private static func setPluginKitEnabled(bundleID: String, pluginPath: String, enabled: Bool) {
        if enabled && FileManager.default.fileExists(atPath: pluginPath) {
            _ = runCommandOutput("/usr/bin/pluginkit", arguments: ["-a", pluginPath])
        }
        let election = enabled ? "use" : "ignore"
        _ = runCommandOutput("/usr/bin/pluginkit", arguments: ["-e", election, "-i", bundleID])
    }

    nonisolated private static func readPBSServicesStatus() -> [String: Bool] {
        let pbsPath = (ConfigStore.shared.realUserHomePath as NSString).appendingPathComponent("Library/Preferences/pbs.plist")
        guard let dict = NSDictionary(contentsOfFile: pbsPath),
              let statusDict = dict["NSServicesStatus"] as? [String: NSDictionary] else {
            return [:]
        }
        var result: [String: Bool] = [:]
        for (key, val) in statusDict {
            if let enabledContext = val["enabled_context_menu"] as? Bool {
                result[key] = enabledContext
            } else if let modes = val["presentation_modes"] as? NSDictionary,
                      let cm = modes["ContextMenu"] as? Bool {
                result[key] = cm
            }
        }
        return result
    }

    nonisolated private static func setSystemServiceEnabled(serviceKey: String, enabled: Bool) {
        let pbsPath = (ConfigStore.shared.realUserHomePath as NSString).appendingPathComponent("Library/Preferences/pbs.plist")
        let rootDict = NSMutableDictionary(contentsOfFile: pbsPath) ?? NSMutableDictionary()
        let statusDict = (rootDict["NSServicesStatus"] as? NSMutableDictionary)
            ?? (rootDict["NSServicesStatus"] as? NSDictionary).map { NSMutableDictionary(dictionary: $0) }
            ?? NSMutableDictionary()

        let entryDict = (statusDict[serviceKey] as? NSMutableDictionary)
            ?? (statusDict[serviceKey] as? NSDictionary).map { NSMutableDictionary(dictionary: $0) }
            ?? NSMutableDictionary()

        entryDict["enabled_context_menu"] = enabled
        entryDict["enabled_services_menu"] = enabled
        let modes = (entryDict["presentation_modes"] as? NSMutableDictionary) ?? NSMutableDictionary()
        modes["ContextMenu"] = enabled
        modes["ServicesMenu"] = enabled
        entryDict["presentation_modes"] = modes

        statusDict[serviceKey] = entryDict
        rootDict["NSServicesStatus"] = statusDict
        rootDict.write(toFile: pbsPath, atomically: true)

        _ = runCommandOutput("/System/Library/CoreServices/pbs", arguments: ["-update"])
    }

    nonisolated private static func runCommandOutput(_ launchPath: String, arguments: [String]) -> String? {
        guard FileManager.default.fileExists(atPath: launchPath) else { return nil }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
