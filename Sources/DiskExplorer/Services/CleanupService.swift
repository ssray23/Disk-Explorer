import Foundation
import AppKit

public class CleanupService {
    private static let trashOperations = FinderTrashOperations()
    
    /// Moves a file to the Trash, allowing it to be recovered by the user.
    /// Finder performs the same FileProvider-aware trash coordination that succeeds when the
    /// user trashes the item manually from Finder, including iCloud Desktop/Documents items.
    @discardableResult
    public static func moveToTrash(url: URL) async throws -> URL? {
        ScanViewModel.writeLog("[CleanupService] moveToTrash started for \(url.path)")
        do {
            ScanViewModel.writeLog("[CleanupService] Asking Finder to move item to Trash...")
            let resultingURL = try await trashOperations.moveToTrash(url)
            ScanViewModel.writeLog("[CleanupService] Finder trash operation succeeded. Resulting URL: \(String(describing: resultingURL))")
            return resultingURL
        } catch let error {
            let nsError = error as NSError
            ScanViewModel.writeLog("[CleanupService] Finder trash operation failed with error: \(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)")
            
            // If the error says the file doesn't exist, it is already gone.
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
                ScanViewModel.writeLog("[CleanupService] File does not exist, treating as success.")
                return url
            }
            
            // Check if the error is a permission error to fallback to administrator script
            let isPermissionError = nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteNoPermissionError
            ScanViewModel.writeLog("[CleanupService] isPermissionError: \(isPermissionError)")
            
            if isPermissionError {
                if !SystemInfoService.hasFullDiskAccess {
                    ScanViewModel.writeLog("[CleanupService] FDA not granted. Throwing permission error.")
                    throw NSError(domain: "CleanupServiceError", code: 513, userInfo: [NSLocalizedDescriptionKey: "Permission denied. Please enable Full Disk Access for Disk Explorer in System Settings > Privacy & Security to delete this item."])
                } else {
                    // We have FDA, but still lack permission. Likely a root-owned file.
                    // Fallback to rm -rf with admin privileges.
                    let safePath = url.path.replacingOccurrences(of: "'", with: "'\\''")
                    let scriptSource = """
                    do shell script "rm -rf '\(safePath)'" with administrator privileges
                    """
                    ScanViewModel.writeLog("[CleanupService] Running AppleScript with administrator privileges...")
                    if let script = NSAppleScript(source: scriptSource) {
                        var errorInfo: NSDictionary?
                        script.executeAndReturnError(&errorInfo)
                        if let errorInfo = errorInfo {
                            let errorMessage = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                            ScanViewModel.writeLog("[CleanupService] AppleScript failed: \(errorMessage)")
                            throw NSError(domain: "CleanupServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete item with admin privileges: \(errorMessage)"])
                        }
                        ScanViewModel.writeLog("[CleanupService] AppleScript succeeded.")
                        return url // Return the original URL to indicate success
                    }
                }
            }
            
            throw error
        }
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
    /// Trashes each item individually so a failure in one cache file doesn't abort the app deletion.
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

/// Bridges Finder's synchronous AppleEvent handling into Swift concurrency without blocking
/// the main actor. Finder already handles the FileProvider-backed trash path correctly.
private final class FinderTrashOperations: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.diskexplorer.finder-trash",
        qos: .userInitiated
    )

    func moveToTrash(_ url: URL) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                autoreleasepool {
                    let scriptSource = """
                    tell application "Finder"
                        delete POSIX file \(Self.appleScriptStringLiteral(url.path))
                    end tell
                    """

                    guard let script = NSAppleScript(source: scriptSource) else {
                        continuation.resume(throwing: NSError(
                            domain: "CleanupServiceError",
                            code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "Could not create Finder trash request."]
                        ))
                        return
                    }

                    var errorInfo: NSDictionary?
                    script.executeAndReturnError(&errorInfo)

                    if let errorInfo {
                        let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown Finder AppleScript error"
                        let code = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? -4
                        continuation.resume(throwing: NSError(
                            domain: "CleanupServiceError",
                            code: code,
                            userInfo: [NSLocalizedDescriptionKey: message]
                        ))
                    } else {
                        continuation.resume(returning: url)
                    }
                }
            }
        }
    }

    private static func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
