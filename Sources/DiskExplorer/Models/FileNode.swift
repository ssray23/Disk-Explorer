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
    /// True if this item is a cloud-synced placeholder whose data hasn't been materialized
    /// locally (iCloud Drive, OneDrive, Dropbox, Google Drive, or any other File Provider).
    /// `size` already reflects actual local disk usage (totalFileAllocatedSize), which is
    /// near-zero for placeholders — this flag exists purely so the UI can show a cloud badge
    /// rather than making the item look like a plain empty file.
    public let isCloudPlaceholder: Bool
    
    public init(name: String, size: Int64, isDirectory: Bool, isAlias: Bool = false, children: [FileNode]? = nil, category: FileCategory = .other, path: URL, isCloudPlaceholder: Bool = false) {
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.isAlias = isAlias
        self.children = children
        self.category = category
        self.path = path
        self.isCloudPlaceholder = isCloudPlaceholder
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
