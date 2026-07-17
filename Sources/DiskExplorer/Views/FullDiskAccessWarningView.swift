import SwiftUI
import AppKit

public struct FullDiskAccessWarningView: View {
    public init() {}
    
    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Disk Access")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Disk Explorer requires Full Disk Access to scan system directories, hidden folders, and calculate accurate sizes. Without it, macOS will silently hide protected files or prompt you constantly.")
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text("Not Granted")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Open System Settings")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(NSColor.controlColor))
                .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Click the button above to open Privacy & Security.")
                    Text("2. Find 'Disk Explorer' in the list and remove it using the minus (-) button.")
                    Text("3. Click the plus (+) button and select the newly built Disk Explorer app.")
                    Text("4. Toggle the switch to ON.")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}
