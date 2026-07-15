import SwiftUI

public struct SystemInfoView: View {
    let info: SystemInfo
    
    public init(info: SystemInfo) {
        self.info = info
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Information")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Mac Model", value: info.macModel, icon: "macbook.and.iphone")
                InfoRow(label: "macOS", value: info.osVersion, icon: "apple.logo")
                InfoRow(label: "Processor", value: info.cpuBrand, icon: "cpu")
                InfoRow(label: "Memory", value: ByteFormatter.format(Int64(info.physicalMemory)), icon: "memorychip")
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Macintosh HD")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Storage Bar
                GeometryReader { geo in
                    let usedRatio = Double(info.usedDiskSpace) / Double(info.totalDiskSpace)
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(usedRatio))
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Text("\(ByteFormatter.format(info.usedDiskSpace)) Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(ByteFormatter.format(info.availableDiskSpace)) Free")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.callout)
            }
        }
    }
}
