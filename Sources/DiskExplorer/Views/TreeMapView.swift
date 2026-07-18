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
    
    @State private var hoveredNodeID: UUID?
    @State private var lastTapTime: Date = Date.distantPast
    @State private var lastTapItem: UUID? = nil
    
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
                            .onTapGesture {
                                let now = Date()
                                if now.timeIntervalSince(lastTapTime) < 0.3 && lastTapItem == tmRect.node.id {
                                    // Double tap
                                    if tmRect.node.isDirectory {
                                        onDrillDown(tmRect.node)
                                    }
                                    lastTapTime = Date.distantPast
                                } else {
                                    // Single tap
                                    onSelect(tmRect.node)
                                    lastTapItem = tmRect.node.id
                                    lastTapTime = now
                                }
                            }
                            .help("\(tmRect.node.name)\n\(ByteFormatter.format(tmRect.node.size))" + (tmRect.node.isDirectory ? "\n(Double-click to open)" : ""))
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: node)
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
    //
    // Implements the algorithm from Bruls, Huizing & van Wijk, "Squarified Treemaps" (1999).
    // Items are grouped into rows (or columns) chosen to keep each rectangle's aspect ratio
    // as close to square as possible, instead of slicing the bounds into one strip per item.
    // This is what keeps a folder with 30+ similarly-sized files readable: they land in a
    // grid of near-square blocks rather than 30 slivers one pixel wide.
    
    private func squarify(node: FileNode, items: [FileNode]?, bounds: CGRect) -> [TreemapRect] {
        let displayItems: [FileNode]
        
        if let items = items {
            if items.isEmpty {
                return [TreemapRect(node: node, rect: bounds)]
            }
            displayItems = items
        } else if let children = node.children, !children.isEmpty {
            displayItems = children
        } else {
            return [TreemapRect(node: node, rect: bounds)]
        }
        
        guard !displayItems.isEmpty else { return [] }
        
        let totalSize = displayItems.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return [] }
        
        // The algorithm assumes descending order, which is guaranteed by DiskScanner.
        // Cap to the largest 150 items to prevent SwiftUI from freezing when diffing/rendering
        // tens of thousands of microscopic ZStack views in a large directory.
        let maxItems = 150
        let itemsToRender = displayItems.count > maxItems ? Array(displayItems.prefix(maxItems)) : displayItems
        
        // Convert byte sizes to pixel area so the aspect-ratio math below operates in real
        // coordinate units instead of arbitrary size units.
        let totalArea = Double(bounds.width) * Double(bounds.height)
        let weightedItems: [(node: FileNode, area: Double)] = itemsToRender.map { item in
            (node: item, area: totalArea * Double(max(item.size, 1)) / Double(totalSize))
        }
        
        var rects: [TreemapRect] = []
        squarifyRow(items: weightedItems, bounds: bounds, rects: &rects)
        return rects
    }
    
    /// Greedily builds one row (or column) at a time: keeps adding the next item to the
    /// current row as long as doing so improves (or doesn't worsen) that row's worst
    /// aspect ratio, then lays the row out along the shorter side of the remaining bounds
    /// and recurses on whatever's left.
    private func squarifyRow(items: [(node: FileNode, area: Double)], bounds: CGRect, rects: inout [TreemapRect]) {
        guard !items.isEmpty else { return }
        guard bounds.width > 0.5, bounds.height > 0.5 else { return }
        
        let shortSide = Double(min(bounds.width, bounds.height))
        var row: [(node: FileNode, area: Double)] = []
        var remaining = items
        
        while !remaining.isEmpty {
            let candidateRow = row + [remaining[0]]
            if row.isEmpty || worstAspectRatio(candidateRow, shortSide: shortSide) <= worstAspectRatio(row, shortSide: shortSide) {
                row = candidateRow
                remaining.removeFirst()
            } else {
                break
            }
        }
        
        let remainingBounds = layoutRow(row, bounds: bounds, rects: &rects)
        squarifyRow(items: remaining, bounds: remainingBounds, rects: &rects)
    }
    
    /// The worst (largest) width:height ratio among rectangles if `row` were laid out as a
    /// single strip of thickness `row's total area / shortSide` along the short side.
    /// Lower is better; 1.0 means every rectangle in the row would be a perfect square.
    private func worstAspectRatio(_ row: [(node: FileNode, area: Double)], shortSide: Double) -> Double {
        guard shortSide > 0 else { return .infinity }
        let rowArea = row.reduce(0.0) { $0 + $1.area }
        guard rowArea > 0 else { return .infinity }
        
        let rowThickness = rowArea / shortSide
        guard rowThickness > 0 else { return .infinity }
        
        return row.reduce(0.0) { worst, item in
            let itemLength = item.area / rowThickness
            let ratio = max(rowThickness / itemLength, itemLength / rowThickness)
            return max(worst, ratio)
        }
    }
    
    /// Lays `row` out as a single strip along the short side of `bounds`, appends the
    /// resulting rects, and returns the leftover bounds for the next row to fill.
    private func layoutRow(_ row: [(node: FileNode, area: Double)], bounds: CGRect, rects: inout [TreemapRect]) -> CGRect {
        let rowArea = row.reduce(0.0) { $0 + $1.area }
        guard rowArea > 0 else { return bounds }
        
        // Wide bounds: lay the row out as a column along the left edge.
        // Tall bounds: lay the row out as a strip along the top edge.
        if bounds.width >= bounds.height {
            let rowWidth = CGFloat(rowArea / Double(bounds.height))
            var y = bounds.minY
            for item in row {
                let itemHeight = CGFloat(item.area / Double(rowWidth))
                rects.append(TreemapRect(node: item.node, rect: CGRect(x: bounds.minX, y: y, width: rowWidth, height: itemHeight)))
                y += itemHeight
            }
            return CGRect(x: bounds.minX + rowWidth, y: bounds.minY, width: bounds.width - rowWidth, height: bounds.height)
        } else {
            let rowHeight = CGFloat(rowArea / Double(bounds.width))
            var x = bounds.minX
            for item in row {
                let itemWidth = CGFloat(item.area / Double(rowHeight))
                rects.append(TreemapRect(node: item.node, rect: CGRect(x: x, y: bounds.minY, width: itemWidth, height: rowHeight)))
                x += itemWidth
            }
            return CGRect(x: bounds.minX, y: bounds.minY + rowHeight, width: bounds.width, height: bounds.height - rowHeight)
        }
    }
}
