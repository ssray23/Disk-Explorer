import Foundation
import AppKit

public class CleanupService {
    
    /// Moves a file to the Trash using NSWorkspace, allowing it to be recovered by the user.
    public static func moveToTrash(url: URL) async throws -> URL? {
        return try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.recycle([url]) { trashedURLs, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: trashedURLs.keys.first)
                }
            }
        }
    }
    
    /// Reveals the file in Finder
    public static func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    /// Returns URLs of associated preferences and caches for an app bundle
    public func getAppAssociatedFiles(appURL: URL) -> [URL] {
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
    
    private func getBundleIdentifier(appURL: URL) -> String? {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }
}
