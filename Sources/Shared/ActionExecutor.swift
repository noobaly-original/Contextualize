import Foundation
import AppKit

public final class ActionExecutor {
    public static let shared = ActionExecutor()

    private init() {}

    @discardableResult
    public func execute(payload: ActionExecutionPayload, config: MenuConfiguration? = nil) -> Bool {
        let activeConfig = config ?? ConfigStore.shared.load()
        guard let item = activeConfig.items.first(where: { $0.id == payload.itemID }) else {
            return false
        }
        return execute(item: item, targetDirectoryPath: payload.targetDirectoryPath, selectedPaths: payload.selectedPaths, config: activeConfig)
    }

    @discardableResult
    public func execute(
        item: ContextMenuItem,
        targetDirectoryPath: String,
        selectedPaths: [String] = [],
        config: MenuConfiguration? = nil
    ) -> Bool {
        let activeConfig = config ?? ConfigStore.shared.load()
        let folderPath = resolveDirectoryPath(targetDirectoryPath: targetDirectoryPath, selectedPaths: selectedPaths)

        switch item.actionKind {
        case .createFile:
            return createFile(for: item, inDirectory: folderPath, config: activeConfig)
        case .openTerminal:
            return openTerminal(atDirectory: folderPath, config: activeConfig)
        case .copyPath:
            let pathToCopy = selectedPaths.first ?? folderPath
            NSPasteboard.general.clearContents()
            return NSPasteboard.general.setString(pathToCopy, forType: .string)
        case .customCommand:
            return runCustomCommand(item.customShellCommand, inDirectory: folderPath)
        }
    }

    private func resolveDirectoryPath(targetDirectoryPath: String, selectedPaths: [String]) -> String {
        var isDir: ObjCBool = false
        if !targetDirectoryPath.isEmpty,
           FileManager.default.fileExists(atPath: targetDirectoryPath, isDirectory: &isDir) {
            if isDir.boolValue {
                return targetDirectoryPath
            } else {
                return (targetDirectoryPath as NSString).deletingLastPathComponent
            }
        }
        if let first = selectedPaths.first {
            if FileManager.default.fileExists(atPath: first, isDirectory: &isDir) {
                return isDir.boolValue ? first : (first as NSString).deletingLastPathComponent
            }
        }
        return ConfigStore.shared.realUserHomePath
    }

    public func createFile(for item: ContextMenuItem, inDirectory directoryPath: String, config: MenuConfiguration) -> Bool {
        let fm = FileManager.default
        let dirURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        let ext = item.fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let baseName = item.localizedBaseFileName(isTR: config.isTurkish)
        let targetURL = uniqueFileURL(in: dirURL, baseName: baseName, fileExtension: ext)

        let created: Bool
        switch item.templateKind {
        case .plainText:
            created = (try? Data().write(to: targetURL, options: .atomic)) != nil

        case .customText:
            let data = item.customInitialText.data(using: .utf8) ?? Data()
            created = (try? data.write(to: targetURL, options: .atomic)) != nil

        case .pagesBlank:
            created = copyBuiltInOrSystemTemplate(
                bundledName: "Blank.pages",
                systemPaths: [
                    "/Applications/Pages Creator Studio.app/Contents/SharedSupport/Templates/00B_Blank_Portrait/ISO.template",
                    "/Applications/Pages Creator Studio.app/Contents/SharedSupport/Templates/Blank/ISO.template",
                    "/Applications/Pages.app/Contents/SharedSupport/Templates/00B_Blank_Portrait/ISO.template",
                    "/Applications/Pages.app/Contents/SharedSupport/Templates/Blank/ISO.template"
                ],
                to: targetURL
            )

        case .keynoteBlank:
            created = copyBuiltInOrSystemTemplate(
                bundledName: "Blank.key",
                systemPaths: [
                    "/Applications/Keynote Creator Studio.app/Contents/SharedSupport/Templates/21_BasicWhite/Wide.kth",
                    "/Applications/Keynote Creator Studio.app/Contents/SharedSupport/Templates/White/Wide.kth",
                    "/Applications/Keynote.app/Contents/SharedSupport/Templates/21_BasicWhite/Wide.kth",
                    "/Applications/Keynote.app/Contents/SharedSupport/Templates/White/Wide.kth"
                ],
                to: targetURL
            )

        case .numbersBlank:
            created = copyBuiltInOrSystemTemplate(
                bundledName: "Blank.numbers",
                systemPaths: [
                    "/Applications/Numbers Creator Studio.app/Contents/SharedSupport/Templates/Blank/Traditional.nmbtemplate",
                    "/Applications/Numbers.app/Contents/SharedSupport/Templates/Blank/Traditional.nmbtemplate"
                ],
                to: targetURL
            )

        case .docxBlank:
            if copyBuiltInOrSystemTemplate(
                bundledName: "Blank.docx",
                systemPaths: [
                    "/Applications/ContextMenuStudio.app/Contents/Resources/Templates/Blank.docx"
                ],
                to: targetURL
            ) && ((try? fm.attributesOfItem(atPath: targetURL.path)[.size] as? UInt64) ?? 0) > 0 {
                created = true
            } else {
                created = generateMinimalDocx(at: targetURL)
            }

        case .customFile:
            if !item.customTemplatePath.isEmpty && fm.fileExists(atPath: item.customTemplatePath) {
                do {
                    try fm.copyItem(at: URL(fileURLWithPath: item.customTemplatePath), to: targetURL)
                    created = true
                } catch {
                    created = false
                }
            } else {
                created = (try? Data().write(to: targetURL, options: .atomic)) != nil
            }
        }

        if created {
            // Ensure current modification timestamp on copied template files
            try? fm.setAttributes([.modificationDate: Date(), .creationDate: Date()], ofItemAtPath: targetURL.path)

            if config.revealCreatedFileInFinder {
                NSWorkspace.shared.selectFile(targetURL.path, inFileViewerRootedAtPath: directoryPath)
            }
            if item.openAfterCreation {
                NSWorkspace.shared.open(targetURL)
            }
        }
        return created
    }

    private func copyBuiltInOrSystemTemplate(bundledName: String, systemPaths: [String], to destinationURL: URL) -> Bool {
        let fm = FileManager.default

        // 1. Check main app bundle Resources/Templates/ or PlugIn parent bundle Resources/Templates/
        var candidateURLs: [URL] = []
        if let resURL = Bundle.main.resourceURL {
            candidateURLs.append(resURL.appendingPathComponent("Templates").appendingPathComponent(bundledName))
            candidateURLs.append(resURL.appendingPathComponent(bundledName))
        }
        // If running from inside .app/Contents/PlugIns/FinderSync.appex, check parent .app/Contents/Resources/Templates/
        let parentAppResources = Bundle.main.bundleURL
            .deletingLastPathComponent() // PlugIns
            .deletingLastPathComponent() // Contents
            .appendingPathComponent("Resources/Templates", isDirectory: true)
            .appendingPathComponent(bundledName)
        candidateURLs.append(parentAppResources)

        for sysPath in systemPaths {
            candidateURLs.append(URL(fileURLWithPath: sysPath))
        }

        for sourceURL in candidateURLs {
            if fm.fileExists(atPath: sourceURL.path) {
                do {
                    if fm.fileExists(atPath: destinationURL.path) {
                        try fm.removeItem(at: destinationURL)
                    }
                    try fm.copyItem(at: sourceURL, to: destinationURL)
                    return true
                } catch {
                    continue
                }
            }
        }

        // Fallback to empty file if no template was found
        return (try? Data().write(to: destinationURL, options: .atomic)) != nil
    }

    private func generateMinimalDocx(at destinationURL: URL) -> Bool {
        let base64Docx = "UEsDBBQAAAAIAFiHXF3XeYTq8QAAALgBAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbH2QzU7DMBCE730Ky9cqccoBIZSkB36OwKE8wMreJFb9J69b2rdn00KREOVozXwz62nXB+/EHjPZGDq5qhspMOhobBg7+b55ru6koALBgIsBO3lEkut+0W6OCUkwHKiTUynpXinSE3qgOiYMrAwxeyj8zKNKoLcworppmlulYygYSlXmDNkvhGgfcYCdK+LpwMr5loyOpHg4e+e6TkJKzmoorKt9ML+Kqq+SmsmThyabaMkGqa6VzOL1jh/0lSfK1qB4g1xewLNRfcRslIl65xmu/0/649o4DFbjhZ/TUo4aiXh77+qL4sGG71+06jR8/wlQSwMEFAAAAAgAWIdcXSAbhuqyAAAALgEAAAsAAABfcmVscy8ucmVsc43Puw6CMBQG4J2naM4uBQdjDIXFmLAafICmPZRGeklbL7y9HRzEODie23fyN93TzOSOIWpnGdRlBQStcFJbxeAynDZ7IDFxK/nsLDJYMELXFs0ZZ57yTZy0jyQjNjKYUvIHSqOY0PBYOo82T0YXDE+5DIp6Lq5cId1W1Y6GTwPagpAVS3rJIPSyBjIsHv/h3ThqgUcnbgZt+vHlayPLPChMDB4uSCrf7TKzQHNKuorZvgBQSwMEFAAAAAgAWIdcXcocEFXzAAAAkwEAABEAAAB3b3JkL2RvY3VtZW50LnhtbFWQy07DMBBF9/0Ky3tqp1QhREm6Y4eEBHyAG08eUuyx7CmhfD12opKyubpHdzwPV6dvM7Ev8GFEW/NsLzkD26IebV/zz4+Xh4KzQMpqNaGFml8h8FOzq+ZSY3sxYInFDjaUc80HIlcKEdoBjAp7dGBj1qE3iiL6XszotfPYQghxgJnEQcpcGDVa3uwYi13PqK/JLuCaKD4JNZW4qV/U/VUFaOnNr7g+699/2Jw2yrJnmfPoh+jz4rHg4l/dq/IxJHQxPh5lqvRjP9CGZyRCs/EE3V06gNLga/4ki4QdIt1hf6EF5W1q2nvbNtF6bnK372x+AVBLAQIUAxQAAAAIAFiHXF3XeYTq8QAAALgBAAATAAAAAAAAAAAAAACAAQAAAABbQ29udGVudF9UeXBlc10ueG1sUEsBAhQDFAAAAAgAWIdcXSAbhuqyAAAALgEAAAsAAAAAAAAAAAAAAIABIgEAAF9yZWxzLy5yZWxzUEsBAhQDFAAAAAgAWIdcXcocEFXzAAAAkwEAABEAAAAAAAAAAAAAAIAB/QEAAHdvcmQvZG9jdW1lbnQueG1sUEsFBgAAAAADAAMAuQAAAB8DAAAAAA=="
        guard let data = Data(base64Encoded: base64Docx) else { return false }
        return (try? data.write(to: destinationURL, options: .atomic)) != nil
    }

    public func uniqueFileURL(in directoryURL: URL, baseName: String, fileExtension: String) -> URL {
        let fm = FileManager.default
        let cleanExt = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        func makeURL(index: Int) -> URL {
            let suffix = index == 1 ? "" : " \(index)"
            let fileName = cleanExt.isEmpty ? "\(baseName)\(suffix)" : "\(baseName)\(suffix).\(cleanExt)"
            return directoryURL.appendingPathComponent(fileName)
        }

        var counter = 1
        var candidate = makeURL(index: counter)
        while fm.fileExists(atPath: candidate.path) {
            counter += 1
            candidate = makeURL(index: counter)
        }
        return candidate
    }

    public func openTerminal(atDirectory directoryPath: String, config: MenuConfiguration) -> Bool {
        let folderURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        let bundleID = config.terminalAppBundleID.isEmpty ? "com.apple.Terminal" : config.terminalAppBundleID

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let openConfig = NSWorkspace.OpenConfiguration()
            openConfig.activates = true
            NSWorkspace.shared.open([folderURL], withApplicationAt: appURL, configuration: openConfig, completionHandler: nil)
            return true
        }

        // Fallback to Process /usr/bin/open -a Terminal
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Terminal", directoryPath]
        do {
            try task.run()
            return true
        } catch {
            return false
        }
    }

    public func runCustomCommand(_ command: String, inDirectory directoryPath: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", trimmed]
        task.currentDirectoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        var env = ProcessInfo.processInfo.environment
        env["CONTEXT_DIR"] = directoryPath
        task.environment = env
        do {
            try task.run()
            return true
        } catch {
            return false
        }
    }
}
