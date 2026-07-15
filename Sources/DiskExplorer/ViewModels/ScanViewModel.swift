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
    @Published public var currentPath: [FileNode] = [] // For breadcrumbs/drill-down
    
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
            if currentPath.isEmpty, let root = rootNode {
                currentPath.append(root)
            }
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
    
    public func trashSelectedNode() async {
        guard let node = selectedNode else { return }
        
        do {
            if let _ = try await CleanupService.moveToTrash(url: node.path) {
                // Remove from tree (simple implementation: just reload or filter.
                // For a robust app, we'd recursively traverse and remove the node, then recompute sizes.)
                // To keep it simple, we just deselect for now.
                self.selectedNode = nil
                // Idealy trigger a re-scan of the current folder or remove from tree.
                print("Successfully trashed \(node.name)")
            }
        } catch {
            print("Failed to trash: \(error)")
        }
    }
    
    public func revealSelectedNode() {
        guard let node = selectedNode else { return }
        CleanupService.revealInFinder(url: node.path)
    }
}
