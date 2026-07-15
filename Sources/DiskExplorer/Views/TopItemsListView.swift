import SwiftUI

public struct TopItemsListView: View {
    let rootNode: FileNode
    let onSelect: (FileNode) -> Void
    var onDoubleTap: ((FileNode) -> Void)?
    
    @State private var showFilesOnly = true
    
    public init(rootNode: FileNode, onSelect: @escaping (FileNode) -> Void, onDoubleTap: ((FileNode) -> Void)? = nil) {
        self.rootNode = rootNode
        self.onSelect = onSelect
        self.onDoubleTap = onDoubleTap
    }
    
    private var topItems: [FileNode] {
        var allItems: [FileNode] = []
        
        func collect(node: FileNode) {
            if showFilesOnly {
                if !node.isDirectory {
                    allItems.append(node)
                }
            } else {
                allItems.append(node)
            }
            if let children = node.children {
                for child in children {
                    collect(node: child)
                }
            }
        }
        
        // Optimize: Don't traverse the whole massive tree if not needed,
        // but for a lightweight app, we do a quick recursive collect on the already-in-memory tree.
        if let children = rootNode.children {
            for child in children {
                collect(node: child)
            }
        }
        
        // Sort by size
        allItems.sort { $0.size > $1.size }
        
        // Deduplicate by path to ensure no weird UI duplication
        var uniqueItems: [FileNode] = []
        var seenPaths: Set<URL> = []
        
        for item in allItems {
            if !seenPaths.contains(item.path) {
                seenPaths.insert(item.path)
                uniqueItems.append(item)
            }
            if uniqueItems.count >= 50 { break }
        }
        
        return uniqueItems
    }
    
    public var body: some View {
        let items = topItems
        let maxItemSize = items.first?.size ?? 1
        
        VStack(alignment: .leading) {
            HStack {
                Text("Largest Items")
                    .font(.headline)
                Spacer()
                Picker("", selection: $showFilesOnly) {
                    Text("Files Only").tag(true)
                    Text("Files & Folders").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 4)
            
            List(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(item.category.color.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: item.isDirectory ? "folder.fill" : "doc.text.fill")
                                .foregroundColor(item.category.color)
                                .font(.system(size: 14))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            let logicalPath = item.path.path
                            let physicalPath = item.physicalPath
                            
                            Text(logicalPath)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                
                            if logicalPath != physicalPath {
                                Text("(\(physicalPath))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        
                        Spacer()
                        
                        Text(ByteFormatter.format(item.size))
                            .font(.callout)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.1))
                            
                            let ratio = Double(item.size) / Double(max(maxItemSize, 1))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: [item.category.color.opacity(0.6), item.category.color], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(ratio))
                        }
                    }
                    .frame(height: 6)
                    .padding(.leading, 44)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if item.isDirectory {
                        onDoubleTap?(item)
                    }
                }
                .onTapGesture(count: 1) {
                    onSelect(item)
                }
            }
            .listStyle(.inset)
        }
    }
}
