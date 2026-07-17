import Foundation

public class DiskScanner: @unchecked Sendable {
    
    public init() {}
    
    private let cancelLock = NSLock()
    private var _isCancelled = false
    
    private var isCancelled: Bool {
        get {
            cancelLock.lock()
            defer { cancelLock.unlock() }
            return _isCancelled
        }
        set {
            cancelLock.lock()
            defer { cancelLock.unlock() }
            _isCancelled = newValue
        }
    }
    
    public func cancel() {
        isCancelled = true
    }
    
    public func scan(url: URL, updateHandler: @escaping @Sendable (FileNode) -> Void, completionHandler: @escaping @MainActor (FileNode?) -> Void) {
        isCancelled = false
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let rootNode = await self.scanRoot(url: url)
            Task { @MainActor in
                completionHandler(rootNode)
            }
        }
    }
    
    /// Entry point for a scan. Parallelizes across the immediate children of `url` using a
    /// TaskGroup bounded to the core count, then falls back to the existing single-threaded
    /// `scanDirectory` for each child's own subtree.
    ///
    /// This deliberately does NOT parallelize recursively at every directory level. Swift's
    /// structured concurrency uses a small cooperative thread pool (roughly one worker per
    /// core), and `scanDirectory` does synchronous, blocking file I/O. A TaskGroup that spawns
    /// child tasks at every recursion level, each of which blocks waiting on further child
    /// tasks, can starve or deadlock that pool once nesting depth exceeds the worker count.
    /// One bounded level of fan-out avoids that risk while still parallelizing the common
    /// case: scanning a home folder, where the real concurrency opportunity is the handful of
    /// large top-level folders (Library, Documents, Movies, Applications...), not the thousands
    /// of individual subdirectories underneath them.
    private func scanRoot(url: URL) async -> FileNode? {
        if isCancelled { return nil }
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        
        // Not a directory, or no children to fan out over: fall back to the plain scan.
        guard isDirectory.boolValue else {
            return scanDirectory(url: url, isRoot: true)
        }
        
        let resourceValues = try? url.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey])
        let isAlias = (resourceValues?.isAliasFile == true) || (resourceValues?.isSymbolicLink == true)
        
        let keys: [URLResourceKey] = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .isPackageKey, .isAliasFileKey, .isSymbolicLinkKey]
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) else {
            return scanDirectory(url: url, isRoot: true)
        }
        
        let immediateChildren = enumerator.compactMap { $0 as? URL }
        
        guard !immediateChildren.isEmpty else {
            let classification = FileCategories.classify(url: url, isDirectory: true)
            return FileNode(
                name: url.lastPathComponent,
                size: 0,
                isDirectory: true,
                isAlias: isAlias,
                children: nil,
                category: classification.category,
                customURL: url
            )
        }
        
        let maxConcurrency = max(2, ProcessInfo.processInfo.activeProcessorCount)
        var children: [FileNode] = []
        children.reserveCapacity(immediateChildren.count)
        
        await withTaskGroup(of: FileNode?.self) { group in
            var iterator = immediateChildren.makeIterator()
            
            func launchNext() {
                guard let childURL = iterator.next() else { return }
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    return self.scanChild(fileURL: childURL)
                }
            }
            
            for _ in 0..<maxConcurrency {
                launchNext()
            }
            
            while let result = await group.next() {
                if let node = result {
                    children.append(node)
                }
                launchNext()
            }
        }
        
        if isCancelled { return nil }
        
        children.sort { $0.size > $1.size }
        let totalSize = children.reduce(0) { $0 + $1.size }
        let classification = FileCategories.classify(url: url, isDirectory: true)
        
        let root = FileNode(
            name: url.lastPathComponent,
            size: totalSize,
            isDirectory: true,
            isAlias: isAlias,
            children: children.isEmpty ? nil : children,
            category: classification.category,
            customURL: url
        )
        
        for child in children {
            child.parent = root
        }
        
        return root
    }
    
    /// Decides whether an enumerated child is a package (treated as an opaque file with a
    /// deep-size fallback) or a regular directory (recursed into normally). Shared by the
    /// shared by the sequential loop in `scanDirectory` and the parallel top-level fan-out in `scanRoot`,
    /// so the package-vs-directory decision only lives in one place.
    private func scanChild(fileURL: URL) -> FileNode? {
        if isCancelled { return nil }
        
        let resourceVals = try? fileURL.resourceValues(forKeys: [.isPackageKey, .isAliasFileKey, .isSymbolicLinkKey])
        let isPackage = resourceVals?.isPackage ?? false
        let childIsAlias = (resourceVals?.isAliasFile == true) || (resourceVals?.isSymbolicLink == true)
        
        if isPackage {
            let size = getDirectorySizeFallback(url: fileURL) // Packages need deep size calc
            let classification = FileCategories.classify(url: fileURL, isDirectory: false)
            return FileNode(
                name: fileURL.lastPathComponent,
                size: size,
                isDirectory: false,
                isAlias: childIsAlias,
                children: nil,
                category: classification.category
            )
        } else {
            return scanDirectory(url: fileURL, isRoot: false)
        }
    }
    
    /// Single-threaded recursive scan of a subtree. Used directly for leaf-level recursion
    /// (called by `scanChild`), and as the whole-tree fallback when `scanRoot` can't fan out
    /// (e.g. the scan target is a single file, not a directory).
    private func scanDirectory(url: URL, isRoot: Bool = false) -> FileNode? {
        if isCancelled { return nil }
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        
        let resourceValues = try? url.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey])
        let isAlias = (resourceValues?.isAliasFile == true) || (resourceValues?.isSymbolicLink == true)
        
        // Base case: it's a file
        if !isDirectory.boolValue {
            let size = self.getFileSize(url: url)
            let classification = FileCategories.classify(url: url, isDirectory: false)
            return FileNode(
                name: url.lastPathComponent,
                size: size,
                isDirectory: false,
                isAlias: isAlias,
                children: nil,
                category: classification.category,
                customURL: isRoot ? url : nil
            )
        }
        
        // It's a directory
        var children: [FileNode] = []
        var totalSize: Int64 = 0
        
        // Note: For extreme performance, `fts_open` is better, but `FileManager.enumerator` 
        // with shallow traversal (skips descendants) is used here to build the tree recursively.
        let keys: [URLResourceKey] = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .isPackageKey, .isAliasFileKey, .isSymbolicLinkKey]
        
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if isCancelled { return nil }
                
                autoreleasepool {
                    if let childNode = scanChild(fileURL: fileURL) {
                        children.append(childNode)
                        totalSize += childNode.size
                    }
                }
            }
        }
        
        children.sort { $0.size > $1.size } // Sort by size descending
        
        let classification = FileCategories.classify(url: url, isDirectory: true)
        let root = FileNode(
            name: url.lastPathComponent,
            size: totalSize,
            isDirectory: true,
            isAlias: isAlias,
            children: children.isEmpty ? nil : children,
            category: classification.category,
            customURL: isRoot ? url : nil
        )
        
        for child in children {
            child.parent = root
        }
        
        return root
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
                autoreleasepool {
                    totalSize += getFileSize(url: fileURL)
                }
            }
        }
        return totalSize
    }
}
