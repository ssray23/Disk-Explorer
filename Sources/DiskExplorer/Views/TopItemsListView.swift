import SwiftUI

public struct TopItemsListView: View {
    let rootNode: FileNode
    let selectedNode: FileNode?
    let onSelect: (FileNode) -> Void
    var onDoubleTap: ((FileNode) -> Void)?
    var onListUpdated: (([FileNode]) -> Void)?
    
    @State private var showFilesOnly = true
    
    public init(rootNode: FileNode, selectedNode: FileNode? = nil, onSelect: @escaping (FileNode) -> Void, onDoubleTap: ((FileNode) -> Void)? = nil, onListUpdated: (([FileNode]) -> Void)? = nil) {
        self.rootNode = rootNode
        self.selectedNode = selectedNode
        self.onSelect = onSelect
        self.onDoubleTap = onDoubleTap
        self.onListUpdated = onListUpdated
    }
    
    @State private var cachedItems: [FileNode] = []
    
    private func updateCachedItems(showFiles: Bool) {
        let root = rootNode
        
        Task.detached {
            var allItems: [FileNode] = []
            
            // If showFiles is true, recursively find all files in the subtree.
            // If false, only show the direct children of the current folder.
            if showFiles {
                var stack: [FileNode] = []
                if let children = root.children {
                    stack.append(contentsOf: children)
                }
                
                while !stack.isEmpty {
                    if Task.isCancelled { return }
                    
                    let node = stack.removeLast()
                    
                    if !node.isDirectory {
                        allItems.append(node)
                    }
                    
                    if let children = node.children {
                        stack.append(contentsOf: children)
                    }
                }
            } else {
                if let children = root.children {
                    let folders = children.filter { $0.isDirectory }
                    allItems.append(contentsOf: folders)
                }
            }
            
            if Task.isCancelled { return }
            allItems.sort { $0.size > $1.size }
            
            var uniqueItems: [FileNode] = []
            var seenPaths: Set<URL> = []
            
            for item in allItems {
                if Task.isCancelled { return }
                if !seenPaths.contains(item.path) {
                    seenPaths.insert(item.path)
                    uniqueItems.append(item)
                }
                if uniqueItems.count >= 150 { break }
            }
            
            if Task.isCancelled { return }
            let finalItems = uniqueItems
            await MainActor.run {
                self.cachedItems = finalItems
                self.onListUpdated?(finalItems)
            }
        }
    }
    
    public var body: some View {
        let items = cachedItems
        let maxItemSize = items.first?.size ?? 1
        
        VStack(alignment: .leading) {
            HStack {
                Text("Largest Items")
                    .font(.headline)
                Spacer()
                Picker("", selection: $showFilesOnly) {
                    Text("Files Only").tag(true)
                    Text("Folders Only").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
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
                                
                            if item.isAlias {
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(2)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .offset(x: 10, y: 10)
                            }
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
                .padding(.horizontal, 8)
                .background(item.id == selectedNode?.id ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(8)
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
        .task(id: "\(rootNode.id)-\(rootNode.version)-\(showFilesOnly)") {
            updateCachedItems(showFiles: showFilesOnly)
        }
    }
}
