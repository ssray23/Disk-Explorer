import Foundation
import AppKit

public class CleanupService {
    
    /// Moves a file to the Trash using NSWorkspace, allowing it to be recovered by the user.
    public static func moveToTrash(url: URL) async throws -> URL? {
        var resultingURL: NSURL? = nil
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL?
    }
    
    /// Reveals the file in Finder
    public static func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    /// Returns URLs of associated preferences and caches for an app bundle
    public static func getAppAssociatedFiles(appURL: URL) -> [URL] {
        guard appURL.pathExtension == "app" else { return [] }
        
        var associatedFiles: [URL] = []
        
        if let bundleIdentifier = getBundleIdentifier(appURL: appURL) {
            let library = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
            
            let possiblePaths = [
                "Caches/\(bundleIdentifier)",
                "Preferences/\(bundleIdentifier).plist",
                "Application Support/\(bundleIdentifier)",
                "Containers/\(bundleIdentifier)",
                "Saved Application State/\(bundleIdentifier).savedState"
            ]
            
            for path in possiblePaths {
                let url = library.appendingPathComponent(path)
                if FileManager.default.fileExists(atPath: url.path) {
                    associatedFiles.append(url)
                }
            }
        }
        
        // Also look by app name
        let appName = appURL.deletingPathExtension().lastPathComponent
        let library = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        let appSupport = library.appendingPathComponent("Application Support/\(appName)")
        if FileManager.default.fileExists(atPath: appSupport.path) {
            associatedFiles.append(appSupport)
        }
        
        return Array(Set(associatedFiles)) // Remove duplicates
    }
    
    /// Trashes an app's associated caches/preferences/support files, then the app bundle itself.
    /// Returns the URLs that were successfully trashed and any errors encountered along the way,
    /// so the caller can report partial failures instead of silently continuing.
    @discardableResult
    public static func deepClean(appURL: URL) async -> (trashed: [URL], errors: [(url: URL, error: Error)]) {
        var trashed: [URL] = []
        var errors: [(url: URL, error: Error)] = []

        for associatedURL in getAppAssociatedFiles(appURL: appURL) {
            do {
                _ = try await moveToTrash(url: associatedURL)
                trashed.append(associatedURL)
            } catch {
                errors.append((associatedURL, error))
            }
        }

        do {
            _ = try await moveToTrash(url: appURL)
            trashed.append(appURL)
        } catch {
            errors.append((appURL, error))
        }

        return (trashed, errors)
    }

    private static func getBundleIdentifier(appURL: URL) -> String? {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }
}
