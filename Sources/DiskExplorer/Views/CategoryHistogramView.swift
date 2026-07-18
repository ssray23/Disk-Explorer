import SwiftUI

public struct CategoryHistogramView: View {
    let rootNode: FileNode
    
    @State private var categorySizes: [(category: FileCategory, size: Int64)] = []
    @State private var isCalculating = true
    @State private var currentRootID: UUID?
    
    public init(rootNode: FileNode) {
        self.rootNode = rootNode
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.headline)
            
            if isCalculating {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                let totalSize = categorySizes.reduce(0) { $0 + $1.size }
                
                if totalSize > 0 {
                    // Stacked Bar
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(categorySizes, id: \.category) { item in
                                let ratio = Double(item.size) / Double(totalSize)
                                let width = max(0, geo.size.width * CGFloat(ratio) - (CGFloat(categorySizes.count) * 2 / CGFloat(categorySizes.count)))
                                if width > 0 {
                                    Rectangle()
                                        .fill(item.category.color)
                                        .frame(width: width)
                                }
                            }
                        }
                        .cornerRadius(6)
                    }
                    .frame(height: 20)
                    
                    // Legend
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(categorySizes, id: \.category) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(item.category.color)
                                        .frame(width: 10, height: 10)
                                    Text(item.category.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(ByteFormatter.format(item.size))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    Text("No categorized files found.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .task(id: "\(rootNode.id)-\(rootNode.size)") {
            await calculateSizes()
        }
    }
    
    private func calculateSizes() async {
        isCalculating = true
        currentRootID = rootNode.id
        
        let node = rootNode
        
        let result = await Task.detached(priority: .userInitiated) { () -> [(category: FileCategory, size: Int64)]? in
            var sizes: [FileCategory: Int64] = [:]
            var stack: [FileNode] = [node]
            var counter = 0
            
            while !stack.isEmpty {
                if Task.isCancelled { return nil }
                
                let n = stack.removeLast()
                if !n.isDirectory {
                    sizes[n.category, default: 0] += n.size
                } else if let children = n.children {
                    stack.append(contentsOf: children)
                }
                
                counter += 1
                if counter % 1000 == 0 {
                    await Task.yield() // Prevent CPU starvation
                }
            }
            
            return sizes.map { (category: $0.key, size: $0.value) }
                .filter { $0.size > 0 }
                .sorted { $0.size > $1.size }
        }.value
        
        guard !Task.isCancelled, let finalResult = result else { return }
        self.categorySizes = finalResult
        self.isCalculating = false
    }
}
