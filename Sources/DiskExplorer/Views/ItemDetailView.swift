import SwiftUI
import AppKit
import UniformTypeIdentifiers
public struct ItemDetailView: View {
    @State private var previewImage: NSImage?
    
    let node: FileNode
    let onTrash: () -> Void
    let onReveal: () -> Void
    let onDeepClean: () -> Void
    
    public init(node: FileNode, onTrash: @escaping () -> Void, onReveal: @escaping () -> Void, onDeepClean: @escaping () -> Void) {
        self.node = node
        self.onTrash = onTrash
        self.onReveal = onReveal
        self.onDeepClean = onDeepClean
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 12) {
                        ZStack {
                            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(node.category.color)
                                
                            if node.isAlias {
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(3)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .offset(x: 12, y: 12)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(node.name)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                
                                if node.isAlias {
                                    Text("(Alias)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
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
                    
                    // Image Preview
                    if let image = previewImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
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
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity)
            
            // Actions (Anchored to bottom)
            VStack(spacing: 12) {
                if node.category == .applications {
                    Button(action: onDeepClean) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Deep Clean Application")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(node.category == .system)
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
                .disabled(node.category == .system)
                
                Button(action: onReveal) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Reveal in Finder")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    if let query = node.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "https://www.google.com/search?q=\(query)+macOS") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Search Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(.regularMaterial)
        .task(id: node.id) {
            previewImage = nil
            if let type = UTType(filenameExtension: node.path.pathExtension), type.conforms(to: .image) {
                let url = node.path
                if let image = await Task.detached(operation: { NSImage(contentsOf: url) }).value {
                    await MainActor.run {
                        self.previewImage = image
                    }
                }
            }
        }
    }
}
