import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers
import AppKit

@MainActor
@Observable
public class ScanViewModel {
    public var systemInfo: SystemInfo?
    public var rootNode: FileNode?
    public var selectedNode: FileNode?
    public var isScanning: Bool = false
    public var isProcessing: Bool = false
    public var processingMessage: String = ""
    public var scanError: String?
    public var actionMessageTitle: String?
    public var actionMessageBody: String?
    public var showActionMessage: Bool = false
    public var currentPath: [FileNode] = [] // For breadcrumbs/drill-down
    public var showFilesOnly: Bool = true
    
    // Derived properties
    public var currentFolderNode: FileNode? {
        currentPath.last ?? rootNode
    }
    
    private let scanner = DiskScanner()
    
    public init() {
        // Disable stdout/stderr buffering so logs flush instantly to app_output.log
        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)
        Self.writeLog("[Disk Explorer] App initialized, unbuffered logging enabled.")
        loadSystemInfo()
    }
    
    public func loadSystemInfo() {
        self.systemInfo = SystemInfoService.getSystemInfo()
    }
    
    public func scanHomeDirectory() {
        startScan(url: URL(fileURLWithPath: NSHomeDirectory()))
    }
    
    public func startScan(url: URL) {
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
    
    public func showOpenPanel() {
        // NSOpenPanel using runModal() is the native macOS folder picker.
        //
        // Why runModal() instead of begin():
        //   runModal() starts a nested event loop that pumps UI events while the panel is
        //   being loaded and displayed. This prevents macOS from thinking the main thread
        //   is unresponsive, eliminating the spinning beach ball. It also natively displays
        //   all Finder sidebar items including iCloud and OneDrive.
        
        Self.writeLog("[Disk Explorer] showOpenPanel() called using native NSOpenPanel runModal().")
        
        let panel = NSOpenPanel()
        panel.title = "Select a folder or drive to scan"
        panel.message = "Select a folder or drive to scan for disk usage."
        panel.prompt = "Scan"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canDownloadUbiquitousContents = true
        panel.canResolveUbiquitousConflicts = true
        
        if panel.runModal() == .OK, let url = panel.url {
            Self.writeLog("[Disk Explorer] Folder selected: \(url.path)")
            startScan(url: url)
        } else {
            Self.writeLog("[Disk Explorer] User cancelled the native folder picker.")
        }
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
    
    public var currentListItems: [FileNode] = []
    
    public func trashSelectedNode() async {
        Self.writeLog("[ScanViewModel] trashSelectedNode() started")
        guard let node = selectedNode else { 
            Self.writeLog("[ScanViewModel] trashSelectedNode(): selectedNode is nil")
            return 
        }
        
        Self.writeLog("[ScanViewModel] Selected node: \(node.name), path: \(node.path.path)")
        isProcessing = true
        processingMessage = "Moving \(node.name) to the Trash..."
        
        do {
            Self.writeLog("[ScanViewModel] Calling CleanupService.moveToTrash(url:)...")
            let trashedURL = try await CleanupService.moveToTrash(url: node.path)
            Self.writeLog("[ScanViewModel] CleanupService.moveToTrash succeeded. Trashed URL: \(String(describing: trashedURL))")
            removeFromTreeAndAdvanceSelection(node)
            isProcessing = false
            self.actionMessageTitle = "Trash Successful"
            self.actionMessageBody = "Successfully moved \(node.name) to the Trash."
            self.showActionMessage = true
            Self.writeLog("[ScanViewModel] Successfully trashed \(node.name)")
        } catch {
            isProcessing = false
            self.actionMessageTitle = "Action Failed"
            self.actionMessageBody = "Failed to trash \(node.name): \(error.localizedDescription)"
            self.showActionMessage = true
            Self.writeLog("[ScanViewModel] Failed to trash \(node.name). Error: \(error)")
        }
    }
    
    /// Deep clean removes an application's associated caches, preferences, and support
    /// files first, then the app bundle itself, instead of just trashing the app and
    /// leaving its leftover files behind.
    public func deepCleanSelectedNode() async {
        guard let node = selectedNode, node.category == .applications else { return }
        
        isProcessing = true
        processingMessage = "Deep cleaning \(node.name)..."
        
        let result = await CleanupService.deepClean(appURL: node.path)
        
        isProcessing = false
        
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
                var modifiedRoot = root
                let _ = removeNode(withID: node.id, targetURL: node.path, from: &modifiedRoot)
                self.rootNode = modifiedRoot
                
                var newPath: [FileNode] = []
                for oldNode in self.currentPath {
                    if let matching = findNode(withID: oldNode.id, targetURL: oldNode.path, in: modifiedRoot) {
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
    
    private func removeNode(withID id: UUID, targetURL: URL, from node: inout FileNode) -> (removed: Bool, sizeDelta: Int64) {
        let targetPath = targetURL.path
        let nodePath = node.path.path
        guard targetPath == nodePath || targetPath.hasPrefix(nodePath + "/") else { return (false, 0) }
        
        guard var children = node.children else { return (false, 0) }
        
        if let index = children.firstIndex(where: { $0.id == id }) {
            let removedSize = children[index].size
            children.remove(at: index)
            node.children = children.isEmpty ? nil : children
            node.size -= removedSize
            return (true, removedSize)
        }
        
        for i in 0..<children.count {
            let result = removeNode(withID: id, targetURL: targetURL, from: &children[i])
            if result.removed {
                node.children = children
                node.size -= result.sizeDelta
                return result
            }
        }
        
        return (false, 0)
    }

    private func findNode(withID id: UUID, targetURL: URL, in node: FileNode) -> FileNode? {
        let targetPath = targetURL.path
        let nodePath = node.path.path
        guard targetPath == nodePath || targetPath.hasPrefix(nodePath + "/") else { return nil }
        
        if node.id == id { return node }
        if let children = node.children {
            for child in children {
                if let found = findNode(withID: id, targetURL: targetURL, in: child) {
                    return found
                }
            }
        }
        return nil
    }

    nonisolated public static func writeLog(_ message: String) {
        let logURL = URL(fileURLWithPath: "/Users/suddharay/Library/Mobile Documents/com~apple~CloudDocs/Mac Projects/Disk Explorer (Swift)/debug.log")
        let line = "[\(Date())] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
