import SwiftUI

public struct TopItemsListView: View {
    let rootNode: FileNode
    let selectedNode: FileNode?
    let onSelect: (FileNode) -> Void
    var onDoubleTap: ((FileNode) -> Void)?
    var onListUpdated: (([FileNode]) -> Void)?
    
    @Binding var showFilesOnly: Bool
    
    public init(rootNode: FileNode, selectedNode: FileNode? = nil, showFilesOnly: Binding<Bool>, onSelect: @escaping (FileNode) -> Void, onDoubleTap: ((FileNode) -> Void)? = nil, onListUpdated: (([FileNode]) -> Void)? = nil) {
        self.rootNode = rootNode
        self.selectedNode = selectedNode
        self._showFilesOnly = showFilesOnly
        self.onSelect = onSelect
        self.onDoubleTap = onDoubleTap
        self.onListUpdated = onListUpdated
    }
    
    @State private var cachedItems: [FileNode] = []
    @State private var lastTapTime: Date = Date.distantPast
    @State private var lastTapItem: ObjectIdentifier? = nil
    
    private func updateCachedItems(showFiles: Bool) async {
        let root = rootNode
        
        let result = await Task.detached(priority: .userInitiated) { () -> [FileNode]? in
            var allItems: [FileNode] = []
            
            // If showFiles is true, recursively find all files in the subtree.
            // If false, only show the direct children of the current folder.
            if showFiles {
                var stack: [FileNode] = []
                if let children = root.children {
                    stack.append(contentsOf: children)
                }
                
                var counter = 0
                while !stack.isEmpty {
                    if Task.isCancelled { return nil }
                    
                    let node = stack.removeLast()
                    
                    if !node.isDirectory {
                        allItems.append(node)
                    }
                    
                    if let children = node.children {
                        stack.append(contentsOf: children)
                    }
                    
                    counter += 1
                    if counter % 1000 == 0 {
                        await Task.yield()
                    }
                }
            } else {
                if let children = root.children {
                    let folders = children.filter { $0.isDirectory }
                    allItems.append(contentsOf: folders)
                }
            }
            
            if Task.isCancelled { return nil }
            allItems.sort { $0.size > $1.size }
            
            var uniqueItems: [FileNode] = []
            var seenPaths: Set<URL> = []
            
            for item in allItems {
                if Task.isCancelled { return nil }
                if !seenPaths.contains(item.path) {
                    seenPaths.insert(item.path)
                    uniqueItems.append(item)
                }
                if uniqueItems.count >= 150 { break }
            }
            
            return uniqueItems
        }.value
        
        guard !Task.isCancelled, let finalItems = result else { return }
        self.cachedItems = finalItems
        self.onListUpdated?(finalItems)
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
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        TopItemRowView(item: item, isSelected: item.id == selectedNode?.id, maxItemSize: maxItemSize)
                            .equatable()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let now = Date()
                                if now.timeIntervalSince(lastTapTime) < 0.3 && lastTapItem == item.id {
                                    // Double tap
                                    if item.isDirectory {
                                        onDoubleTap?(item)
                                    }
                                    // Reset to prevent triple-tap firing double-tap twice
                                    lastTapTime = Date.distantPast
                                } else {
                                    // Single tap
                                    onSelect(item)
                                    lastTapItem = item.id
                                    lastTapTime = now
                                }
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .task(id: "\(rootNode.id)-\(rootNode.version)-\(showFilesOnly)") {
            await updateCachedItems(showFiles: showFilesOnly)
        }
    }
}

struct TopItemRowView: View, Equatable {
    let item: FileNode
    let isSelected: Bool
    let maxItemSize: Int64
    
    nonisolated static func == (lhs: TopItemRowView, rhs: TopItemRowView) -> Bool {
        return lhs.item.id == rhs.item.id && lhs.isSelected == rhs.isSelected && lhs.maxItemSize == rhs.maxItemSize
    }
    
    var body: some View {
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
                    let logicalPath = item.physicalPath
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
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(8)
    }
}
