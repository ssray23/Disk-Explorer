import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public class ScanViewModel: ObservableObject {
    @Published public var systemInfo: SystemInfo?
    @Published public var rootNode: FileNode?
    @Published public var selectedNode: FileNode?
    @Published public var isScanning: Bool = false
    @Published public var scanError: String?
    @Published public var actionMessageTitle: String?
    @Published public var actionMessageBody: String?
    @Published public var showActionMessage: Bool = false
    @Published public var currentPath: [FileNode] = [] // For breadcrumbs/drill-down
    @Published public var showFilesOnly: Bool = false
    
    // Derived properties
    public var currentFolderNode: FileNode? {
        currentPath.last ?? rootNode
    }
    
    private let scanner = DiskScanner()
    
    public init() {
        loadSystemInfo()
    }
    
    public func loadSystemInfo() {
        self.systemInfo = SystemInfoService.getSystemInfo()
    }
    
    public func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan Folder"
        panel.message = "Select a folder or drive to scan for disk usage."
        
        if panel.runModal() == .OK, let url = panel.url {
            startScan(url: url)
        }
    }
    
    public func scanHomeDirectory() {
        startScan(url: URL(fileURLWithPath: NSHomeDirectory()))
    }
    
    private func startScan(url: URL) {
        isScanning = true
        rootNode = nil
        selectedNode = nil
        currentPath = []
        scanError = nil
        
        scanner.scan(url: url, updateHandler: { _ in
            // For future: update progress if needed
        }, completionHandler: { [weak self] resultNode in
            self?.isScanning = false
            if let node = resultNode {
                self?.rootNode = node
            } else {
                self?.scanError = "Failed to scan directory or scan was cancelled."
            }
        })
    }
    
    public func cancelScan() {
        scanner.cancel()
        isScanning = false
    }
    
    public func drillDown(to node: FileNode) {
        if node.isDirectory {
            currentPath.append(node)
            selectedNode = nil
        }
    }
    
    public func navigateBack(to index: Int) {
        guard index >= 0 && index < currentPath.count else { return }
        if index == 0 {
            // Back to root
            currentPath = []
        } else {
            currentPath = Array(currentPath.prefix(index + 1))
        }
        selectedNode = nil
    }
    
    public func navigateUp() {
        guard !currentPath.isEmpty else { return }
        currentPath.removeLast()
        selectedNode = nil
    }
    
    @Published public var currentListItems: [FileNode] = []
    
    public func trashSelectedNode() async {
        guard let node = selectedNode else { return }
        
        do {
            let _ = try await CleanupService.moveToTrash(url: node.path)
            removeFromTreeAndAdvanceSelection(node)
            print("Successfully trashed \(node.name)")
        } catch {
            self.actionMessageTitle = "Action Failed"
            self.actionMessageBody = "Failed to trash \(node.name): \(error.localizedDescription)"
            self.showActionMessage = true
            print("Failed to trash: \(error)")
        }
    }
    
    /// Deep clean removes an application's associated caches, preferences, and support
    /// files first, then the app bundle itself, instead of just trashing the app and
    /// leaving its leftover files behind.
    public func deepCleanSelectedNode() async {
        guard let node = selectedNode, node.category == .applications else { return }
        
        let result = await CleanupService.deepClean(appURL: node.path)
        
        for (url, error) in result.errors {
            print("Failed to trash \(url.lastPathComponent) during deep clean: \(error)")
        }
        
        if result.trashed.contains(node.path) {
            removeFromTreeAndAdvanceSelection(node)
            self.actionMessageTitle = "Deep Clean Successful"
            self.actionMessageBody = "Successfully deep cleaned \(node.name).\n\(result.trashed.count) item(s) were moved to the Trash."
            self.showActionMessage = true
            print("Deep cleaned \(node.name): removed \(result.trashed.count) item(s)")
        } else if let appError = result.errors.first(where: { $0.url == node.path }) {
            self.actionMessageTitle = "Action Failed"
            self.actionMessageBody = "Failed to deep clean \(node.name): \(appError.error.localizedDescription)"
            self.showActionMessage = true
        } else {
            self.actionMessageTitle = "Action Failed"
            self.actionMessageBody = "Failed to deep clean \(node.name): Unknown error"
            self.showActionMessage = true
        }
    }
    
    /// Removes a trashed node from the in-memory tree, re-resolves the breadcrumb path,
    /// and picks a sensible next item to select. Shared by both trash and deep clean,
    /// since both end with the same "node is gone, update the UI" step.
    private func removeFromTreeAndAdvanceSelection(_ node: FileNode) {
        // Determine the next item to select
        var nextNodeToSelect: FileNode? = nil
        
        // Primary: Try to find the next item from the exactly rendered list in TopItemsListView
        if let index = currentListItems.firstIndex(where: { $0.id == node.id }) {
            if index + 1 < currentListItems.count {
                nextNodeToSelect = currentListItems[index + 1]
            } else if index - 1 >= 0 {
                nextNodeToSelect = currentListItems[index - 1]
            }
        }
        
        // Fallback: If not found in the list (e.g., trashing a folder from the TreeMap while the list shows "Files Only"),
        // fallback to finding the next sibling in the current folder.
        if nextNodeToSelect == nil {
            if let currentFolder = self.currentFolderNode, let children = currentFolder.children {
                let sortedChildren = children.sorted { $0.size > $1.size }
                if let index = sortedChildren.firstIndex(where: { $0.id == node.id }) {
                    if index + 1 < sortedChildren.count {
                        nextNodeToSelect = sortedChildren[index + 1]
                    } else if index - 1 >= 0 {
                        nextNodeToSelect = sortedChildren[index - 1]
                    }
                }
            }
        }
        
        if let root = self.rootNode {
            if root.id == node.id {
                self.rootNode = nil
                self.currentPath = []
            } else {
                let _ = removeNode(withID: node.id, from: root)
                root.version += 1
                self.rootNode = root
                self.objectWillChange.send()
                
                var newPath: [FileNode] = []
                for oldNode in self.currentPath {
                    if let matching = findNode(withID: oldNode.id, in: root) {
                        newPath.append(matching)
                    } else {
                        break
                    }
                }
                self.currentPath = newPath
            }
        }
        
        self.selectedNode = nextNodeToSelect
        self.loadSystemInfo()
    }
    
    public func revealSelectedNode() {
        guard let node = selectedNode else { return }
        CleanupService.revealInFinder(url: node.path)
    }
    
    // MARK: - Tree Mutating Utilities
    
    private func removeNode(withID id: ObjectIdentifier, from node: FileNode) -> (removed: Bool, sizeDelta: Int64) {
        guard var children = node.children else { return (false, 0) }
        
        if let index = children.firstIndex(where: { $0.id == id }) {
            let removedSize = children[index].size
            children.remove(at: index)
            node.children = children
            node.size -= removedSize
            return (true, removedSize)
        }
        
        for child in children {
            let result = removeNode(withID: id, from: child)
            if result.removed {
                node.size -= result.sizeDelta
                return result
            }
        }
        
        return (false, 0)
    }

    private func findNode(withID id: ObjectIdentifier, in node: FileNode) -> FileNode? {
        if node.id == id { return node }
        if let children = node.children {
            for child in children {
                if let found = findNode(withID: id, in: child) {
                    return found
                }
            }
        }
        return nil
    }
}
