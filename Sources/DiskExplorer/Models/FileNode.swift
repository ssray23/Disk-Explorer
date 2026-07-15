import Foundation

public struct FileNode: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var version = 0
    public let name: String
    public let path: URL
    public let physicalPath: String
    public var size: Int64
    public let isDirectory: Bool
    public let isAlias: Bool
    public var children: [FileNode]?
    public var category: FileCategory
    public var explanation: String
    
    public init(name: String, path: URL, physicalPath: String, size: Int64, isDirectory: Bool, isAlias: Bool = false, children: [FileNode]? = nil, category: FileCategory = .other, explanation: String = "") {
        self.name = name
        self.path = path
        self.physicalPath = physicalPath
        self.size = size
        self.isDirectory = isDirectory
        self.isAlias = isAlias
        self.children = children
        self.category = category
        self.explanation = explanation
    }
    
    // Custom Hashable/Equatable to avoid deep recursion if not needed, 
    // but default synthesized is usually fine.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(version)
    }
    
    public static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }
}
