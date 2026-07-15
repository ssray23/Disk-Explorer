import Foundation

public class DiskScanner: @unchecked Sendable {
    
    public init() {}
    
    private var isCancelled = false
    
    public func cancel() {
        isCancelled = true
    }
    
    public func scan(url: URL, updateHandler: @escaping @Sendable (FileNode) -> Void, completionHandler: @escaping @MainActor (FileNode?) -> Void) {
        isCancelled = false
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let rootNode = self.scanDirectory(url: url)
            Task { @MainActor in
                completionHandler(rootNode)
            }
        }
    }
    
    private func scanDirectory(url: URL, physicalPath: String? = nil) -> FileNode? {
        if isCancelled { return nil }
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        
        let currentPhysicalPath = physicalPath ?? url.path
        
        // Base case: it's a file
        if !isDirectory.boolValue {
            let size = self.getFileSize(url: url)
            let classification = FileCategories.classify(url: url, isDirectory: false)
            return FileNode(
                name: url.lastPathComponent,
                path: url,
                physicalPath: currentPhysicalPath,
                size: size,
                isDirectory: false,
                children: nil,
                category: classification.category,
                explanation: classification.explanation
            )
        }
        
        // It's a directory
        var children: [FileNode] = []
        var totalSize: Int64 = 0
        
        // Note: For extreme performance, `fts_open` is better, but `FileManager.enumerator` 
        // with shallow traversal (skips descendants) is used here to build the tree recursively.
        let keys: [URLResourceKey] = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .isPackageKey]
        
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if isCancelled { return nil }
                
                // If it's a package (like .app), we treat it as a file to avoid descending into it
                let isPackage = (try? fileURL.resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false
                
                if isPackage {
                    let size = getDirectorySizeFallback(url: fileURL) // Packages need deep size calc
                    let classification = FileCategories.classify(url: fileURL, isDirectory: false)
                    let childPhysicalPath = (currentPhysicalPath as NSString).appendingPathComponent(fileURL.lastPathComponent)
                    let node = FileNode(name: fileURL.lastPathComponent, path: fileURL, physicalPath: childPhysicalPath, size: size, isDirectory: false, children: nil, category: classification.category, explanation: classification.explanation)
                    children.append(node)
                    totalSize += size
                } else {
                    let childPhysicalPath = (currentPhysicalPath as NSString).appendingPathComponent(fileURL.lastPathComponent)
                    if let childNode = scanDirectory(url: fileURL, physicalPath: childPhysicalPath) {
                        children.append(childNode)
                        totalSize += childNode.size
                    }
                }
            }
        }
        
        children.sort { $0.size > $1.size } // Sort by size descending
        
        let classification = FileCategories.classify(url: url, isDirectory: true)
        return FileNode(
            name: url.lastPathComponent,
            path: url,
            physicalPath: currentPhysicalPath,
            size: totalSize,
            isDirectory: true,
            children: children.isEmpty ? nil : children,
            category: classification.category,
            explanation: classification.explanation
        )
    }
    
    private func getFileSize(url: URL) -> Int64 {
        do {
            let values = try url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            if let allocated = values.totalFileAllocatedSize, allocated > 0 {
                return Int64(allocated)
            }
            if let size = values.fileSize {
                return Int64(size)
            }
        } catch {
            // Ignore permission errors
        }
        return 0
    }
    
    // Fallback for getting the size of a package (e.g. .app) where we don't build the tree
    private func getDirectorySizeFallback(url: URL) -> Int64 {
        var totalSize: Int64 = 0
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey]
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) {
            for case let fileURL as URL in enumerator {
                totalSize += getFileSize(url: fileURL)
            }
        }
        return totalSize
    }
}
