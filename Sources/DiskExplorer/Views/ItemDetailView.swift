import SwiftUI

public struct ItemDetailView: View {
    let node: FileNode
    let onTrash: () -> Void
    let onReveal: () -> Void
    
    public init(node: FileNode, onTrash: @escaping () -> Void, onReveal: @escaping () -> Void) {
        self.node = node
        self.onTrash = onTrash
        self.onReveal = onReveal
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundColor(node.category.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    
                    Text(ByteFormatter.format(node.size))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Category Badge
            HStack {
                Text(node.category.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(node.category.color.opacity(0.2))
                    .foregroundColor(node.category.color)
                    .cornerRadius(4)
            }
            
            // Explanation
            VStack(alignment: .leading, spacing: 8) {
                Text("What is this?")
                    .font(.headline)
                
                Text(node.explanation)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Path
            VStack(alignment: .leading, spacing: 4) {
                Text("Path")
                    .font(.caption)
                    .foregroundColor(.secondary)
                let logicalPath = node.path.path
                let physicalPath = node.physicalPath
                
                Text(logicalPath != physicalPath ? "\(logicalPath) (\(physicalPath))" : logicalPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .contextMenu {
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(node.path.path, forType: .string)
                        }
                        if logicalPath != physicalPath {
                            Button("Copy Physical Path") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(physicalPath, forType: .string)
                            }
                        }
                    }
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                if node.category == .applications {
                    Button(action: {
                        // Deep Clean (For now just move to trash, full logic would invoke CleanupService deep clean)
                        onTrash()
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Deep Clean Application")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                
                Button(action: onTrash) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Move to Trash")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Button(action: onReveal) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Reveal in Finder")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}
