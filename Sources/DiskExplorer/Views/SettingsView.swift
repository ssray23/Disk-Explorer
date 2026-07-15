import SwiftUI

public struct SettingsView: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    
    public init() {}
    
    public var body: some View {
        TabView {
            // Permissions Tab
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundColor(permissionsManager.hasFullDiskAccess ? .green : .orange)
                        .frame(width: 60)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Disk Access")
                            .font(.headline)
                        
                        Text("Disk Explorer requires Full Disk Access to scan system directories, hidden folders, and calculate accurate sizes. Without it, macOS will silently hide protected files or prompt you constantly.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(permissionsManager.hasFullDiskAccess ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(permissionsManager.hasFullDiskAccess ? "Granted" : "Not Granted")
                                .fontWeight(.semibold)
                                .foregroundColor(permissionsManager.hasFullDiskAccess ? .green : .red)
                        }
                        .padding(.top, 4)
                        
                        if !permissionsManager.hasFullDiskAccess {
                            Button(action: {
                                permissionsManager.openSystemSettings()
                            }) {
                                Text("Open System Settings")
                                    .fontWeight(.medium)
                            }
                            .padding(.top, 8)
                            
                            Text("1. Click the button above to open Privacy & Security.\n2. Find 'Disk Explorer' in the list (or add it using the + button).\n3. Toggle the switch to ON.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(32)
            .tabItem {
                Label("Permissions", systemImage: "hand.raised.fill")
            }
        }
        .frame(width: 500, height: 350)
    }
}
