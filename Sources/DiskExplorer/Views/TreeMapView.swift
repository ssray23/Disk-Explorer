import SwiftUI

struct TreemapRect {
    let node: FileNode
    var rect: CGRect
}

public struct TreeMapView: View {
    let node: FileNode
    let selectedNode: FileNode?
    let flatItems: [FileNode]?
    let onSelect: (FileNode) -> Void
    let onDrillDown: (FileNode) -> Void
    var onGoUp: (() -> Void)? = nil
    
    @State private var hoveredNodeID: UUID? = nil
    
    public init(node: FileNode, selectedNode: FileNode?, flatItems: [FileNode]? = nil, onSelect: @escaping (FileNode) -> Void, onDrillDown: @escaping (FileNode) -> Void, onGoUp: (() -> Void)? = nil) {
        self.node = node
        self.selectedNode = selectedNode
        self.flatItems = flatItems
        self.onSelect = onSelect
        self.onDrillDown = onDrillDown
        self.onGoUp = onGoUp
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geo in
                let rects = squarify(node: node, items: flatItems, bounds: CGRect(origin: .zero, size: geo.size))
                
                ZStack {
                    ForEach(rects, id: \.node.id) { tmRect in
                        let isSelected = selectedNode?.id == tmRect.node.id
                        let isHovered = hoveredNodeID == tmRect.node.id
                        let paddedRect = tmRect.rect.insetBy(dx: 3, dy: 3)
                        let width = max(0, paddedRect.width)
                        let height = max(0, paddedRect.height)
                        
                        if width > 0 && height > 0 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                tmRect.node.category.color.opacity(isSelected ? 0.9 : (isHovered ? 0.7 : 0.4)),
                                                tmRect.node.category.color.opacity(isSelected ? 1.0 : (isHovered ? 0.8 : 0.6))
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 1, y: 1)
                                
                                // Show name if block is big enough
                                if width > 70 && height > 50 {
                                    VStack(spacing: 6) {
                                        Image(systemName: tmRect.node.isDirectory ? "folder.fill" : "doc.text.fill")
                                            .foregroundColor(.white.opacity(0.9))
                                            .font(.title3)
                                        Text(tmRect.node.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .padding(4)
                                    .allowsHitTesting(false)
                                }
                            }
                            .frame(width: width, height: height)
                            .position(x: paddedRect.midX, y: paddedRect.midY)
                            .onHover { hovering in
                                if hovering {
                                    hoveredNodeID = tmRect.node.id
                                } else if hoveredNodeID == tmRect.node.id {
                                    hoveredNodeID = nil
                                }
                            }
                            .onTapGesture(count: 2) {
                                if tmRect.node.isDirectory {
                                    onDrillDown(tmRect.node)
                                }
                            }
                            .onTapGesture(count: 1) {
                                onSelect(tmRect.node)
                            }
                            .help("\(tmRect.node.name)\n\(ByteFormatter.format(tmRect.node.size))" + (tmRect.node.isDirectory ? "\n(Double-click to open)" : ""))
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: node.version)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: flatItems?.count)
                .animation(.easeInOut(duration: 0.2), value: selectedNode?.id)
            }
            
            if let onGoUp = onGoUp {
                Button(action: onGoUp) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                        Text("Go Up")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .padding(12)
            }
        }
    }
    
    // MARK: - Squarified Treemap Algorithm
    
    private func squarify(node: FileNode, items: [FileNode]?, bounds: CGRect) -> [TreemapRect] {
        let displayItems: [FileNode]
        
        if let items = items {
            displayItems = items
        } else if let children = node.children, !children.isEmpty {
            displayItems = children
        } else {
            return [TreemapRect(node: node, rect: bounds)]
        }
        
        guard !displayItems.isEmpty else { return [] }
        
        let totalSize = displayItems.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return [] }
        
        var rects: [TreemapRect] = []
        var remainingBounds = bounds
        var currentRemainingSize = totalSize
        
        for child in displayItems {
            let childSize = max(child.size, 1)
            let ratio = Double(childSize) / Double(max(currentRemainingSize, 1))
            
            if remainingBounds.width > remainingBounds.height {
                // Split vertically
                let width = remainingBounds.width * CGFloat(ratio)
                let rect = CGRect(x: remainingBounds.minX, y: remainingBounds.minY, width: width, height: remainingBounds.height)
                rects.append(TreemapRect(node: child, rect: rect))
                remainingBounds = CGRect(x: remainingBounds.minX + width, y: remainingBounds.minY, width: remainingBounds.width - width, height: remainingBounds.height)
            } else {
                // Split horizontally
                let height = remainingBounds.height * CGFloat(ratio)
                let rect = CGRect(x: remainingBounds.minX, y: remainingBounds.minY, width: remainingBounds.width, height: height)
                rects.append(TreemapRect(node: child, rect: rect))
                remainingBounds = CGRect(x: remainingBounds.minX, y: remainingBounds.minY + height, width: remainingBounds.width, height: remainingBounds.height - height)
            }
            
            currentRemainingSize -= child.size
            if currentRemainingSize < 0 { currentRemainingSize = 0 }
        }
        
        return rects
    }
}
