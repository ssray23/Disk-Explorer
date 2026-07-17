import Foundation

public final class FileNode: Identifiable, Hashable, @unchecked Sendable {
    public let name: String
    public var size: Int64
    public let isDirectory: Bool
    public let isAlias: Bool
    public var children: [FileNode]?
    public var category: FileCategory
    
    public weak var parent: FileNode?
    public var customURL: URL?
    public var version = 0
    
    public init(name: String, size: Int64, isDirectory: Bool, isAlias: Bool = false, children: [FileNode]? = nil, category: FileCategory = .other, parent: FileNode? = nil, customURL: URL? = nil) {
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.isAlias = isAlias
        self.children = children
        self.category = category
        self.parent = parent
        self.customURL = customURL
    }
    
    public var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
    
    public var path: URL {
        if let customURL = customURL {
            return customURL
        }
        return URL(fileURLWithPath: physicalPath, isDirectory: isDirectory)
    }
    
    public var physicalPath: String {
        if let customURL = customURL {
            return customURL.path
        }
        var components: [String] = []
        var current: FileNode? = self
        var basePath = ""
        
        while let node = current {
            if let custom = node.customURL {
                basePath = custom.path
                break
            }
            components.append(node.name)
            current = node.parent
        }
        
        let subPath = components.reversed().joined(separator: "/")
        if basePath.hasSuffix("/") {
            return basePath + subPath
        } else {
            return basePath + "/" + subPath
        }
    }
    
    public var explanation: String {
        return FileCategories.classify(url: path, isDirectory: isDirectory).explanation
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(version)
    }
    
    public static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs === rhs && lhs.version == rhs.version
    }
}
