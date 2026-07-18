import Foundation

public struct FileNode: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let name: String
    public var size: Int64
    public let isDirectory: Bool
    public let isAlias: Bool
    public var children: [FileNode]?
    public var category: FileCategory
    public let path: URL
    
    public init(name: String, size: Int64, isDirectory: Bool, isAlias: Bool = false, children: [FileNode]? = nil, category: FileCategory = .other, path: URL) {
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.isAlias = isAlias
        self.children = children
        self.category = category
        self.path = path
    }
    
    public var explanation: String {
        return FileCategories.classify(url: path, isDirectory: isDirectory).explanation
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id
    }
}
