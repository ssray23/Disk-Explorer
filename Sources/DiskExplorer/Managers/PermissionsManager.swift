import Foundation
import AppKit

@MainActor
public class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()
    
    @Published public var hasFullDiskAccess: Bool = false
    
    private var timer: Timer?
    
    private init() {
        checkFullDiskAccess()
        
        // Poll every 2 seconds to instantly update the UI if the user grants access in System Settings
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkFullDiskAccess()
            }
        }
    }
    
    public func checkFullDiskAccess() {
        // TCC (Transparency, Consent, and Control) and Safari directories require FDA to read their contents.
        let tccPath = "/Library/Application Support/com.apple.TCC"
        let safariPath = NSHomeDirectory() + "/Library/Safari"
        
        let canReadTCC = (try? FileManager.default.contentsOfDirectory(atPath: tccPath)) != nil
        let canReadSafari = (try? FileManager.default.contentsOfDirectory(atPath: safariPath)) != nil
        
        let hasAccess = canReadTCC || canReadSafari
        
        if self.hasFullDiskAccess != hasAccess {
            self.hasFullDiskAccess = hasAccess
        }
    }
    
    public func openSystemSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
