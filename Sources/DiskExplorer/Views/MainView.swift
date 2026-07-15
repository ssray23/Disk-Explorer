import SwiftUI

public struct MainView: View {
    public enum ViewMode {
        case explorer
        case deepClean
    }
    
    @State private var viewMode: ViewMode = .explorer
    @StateObject private var viewModel = ScanViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack {
                if let info = viewModel.systemInfo {
                    SystemInfoView(info: info)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        viewMode = .explorer
                        viewModel.selectFolder()
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.magnifyingglass")
                            Text("Scan Folder...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        viewMode = .explorer
                        viewModel.scanHomeDirectory()
                    }) {
                        HStack {
                            Image(systemName: "house")
                            Text("Scan Home Folder")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        viewMode = .deepClean
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Deep Clean")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .frame(minWidth: 250)
            .ignoresSafeArea(.all, edges: .top)
            
        } detail: {
            // Main Content
            if viewMode == .deepClean {
                DeepCleanView(onCleanCompleted: {
                    viewModel.loadSystemInfo()
                })
                    .ignoresSafeArea(.all, edges: .top)
            } else if viewModel.isScanning {
                VStack {
                    ProgressView("Scanning Disk...")
                    Button("Cancel") {
                        viewModel.cancelScan()
                    }
                    .padding(.top)
                }
            } else if let error = viewModel.scanError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .padding()
                }
            } else if let rootNode = viewModel.rootNode {
                HStack(spacing: 0) {
                    // Center: Treemap & List
                    VStack(spacing: 0) {
                        // Header area: Path + Breadcrumbs
                        HStack {
                            if viewModel.currentPath.isEmpty {
                                Text(rootNode.path.path)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(gradient: Gradient(colors: [.cyan, .blue]), startPoint: .leading, endPoint: .trailing)
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        // Root button
                                        Button(action: {
                                            viewModel.currentPath = []
                                            viewModel.selectedNode = nil
                                        }) {
                                            Text(rootNode.name)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    LinearGradient(gradient: Gradient(colors: [.cyan, .blue]), startPoint: .leading, endPoint: .trailing)
                                                )
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        
                                        ForEach(Array(viewModel.currentPath.enumerated()), id: \.element.id) { index, pathNode in
                                            Button(action: {
                                                viewModel.navigateBack(to: index)
                                            }) {
                                                Text(pathNode.name)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(Color.secondary.opacity(0.1))
                                                    .cornerRadius(6)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            if index < viewModel.currentPath.count - 1 {
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.secondary)
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.windowBackgroundColor))
                        
                        Divider()
                        
                        if let currentFolder = viewModel.currentFolderNode {
                            VSplitView {
                                TreeMapView(
                                    node: currentFolder,
                                    selectedNode: viewModel.selectedNode,
                                    onSelect: { node in
                                        viewModel.selectedNode = node
                                    },
                                    onDrillDown: { node in
                                        viewModel.drillDown(to: node)
                                    },
                                    onGoUp: viewModel.currentPath.isEmpty ? nil : {
                                        viewModel.navigateUp()
                                    }
                                )
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .frame(minHeight: 150)
                                
                                VStack(spacing: 0) {
                                    CategoryHistogramView(rootNode: currentFolder)
                                    
                                    Divider()
                                    
                                    TopItemsListView(
                                        rootNode: currentFolder,
                                        onSelect: { node in
                                            viewModel.selectedNode = node
                                        },
                                        onDoubleTap: { node in
                                            viewModel.drillDown(to: node)
                                        }
                                    )
                                    .frame(minHeight: 150)
                                    .background(Color(NSColor.windowBackgroundColor))
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Right Sidebar: Inspector
                    if let selectedNode = viewModel.selectedNode {
                        ItemDetailView(
                            node: selectedNode,
                            onTrash: {
                                Task {
                                    await viewModel.trashSelectedNode()
                                }
                            },
                            onReveal: {
                                viewModel.revealSelectedNode()
                            }
                        )
                        .frame(width: 300)
                        .background(Color(NSColor.windowBackgroundColor))
                    } else {
                        VStack {
                            Image(systemName: "cursorarrow.rays")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Select an item to view details")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                        .frame(width: 300)
                        .background(Color(NSColor.windowBackgroundColor))
                    }
                }
                .ignoresSafeArea(.all, edges: .top)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Ready to Scan")
                        .font(.title)
                    
                    Text("Select a folder or drive from the sidebar to analyze disk space usage.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
    }
}
