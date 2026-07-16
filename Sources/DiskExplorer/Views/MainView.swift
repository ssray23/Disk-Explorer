import SwiftUI

public struct MainView: View {
    public enum ViewMode {
        case explorer
        case deepClean
    }
    
    @State private var viewMode: ViewMode = .explorer
    @StateObject private var viewModel = ScanViewModel()
    
    @AppStorage("inspectorWidth") private var inspectorWidth: Double = 300
    @AppStorage("treemapHeight") private var treemapHeight: Double = 300
    @State private var dragInitialHeight: Double? = nil
    public init() {}
    
    public var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
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
            .navigationSplitViewColumnWidth(min: 250, ideal: 250, max: 350)
            .ignoresSafeArea(.all, edges: .top)
            .toolbar(removing: .sidebarToggle)
            
        } content: {
            // Main Content
            if viewMode == .deepClean {
                DeepCleanView(onCleanCompleted: {
                    viewModel.loadSystemInfo()
                })
                .navigationSplitViewColumnWidth(min: 500, ideal: 800)
                .ignoresSafeArea(.all, edges: .top)
            } else if viewModel.isScanning {
                VStack {
                    ProgressView("Scanning Disk...")
                    Button("Cancel") {
                        viewModel.cancelScan()
                    }
                    .padding(.top)
                }
                .navigationSplitViewColumnWidth(min: 500, ideal: 800)
                .ignoresSafeArea(.all, edges: .top)
            } else if let error = viewModel.scanError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .padding()
                }
                .navigationSplitViewColumnWidth(min: 500, ideal: 800)
                .ignoresSafeArea(.all, edges: .top)
            } else if let rootNode = viewModel.rootNode {
                VStack(spacing: 0) {
                    // Header area: Path + Breadcrumbs
                    HStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                // Root button
                                Button(action: {
                                    viewModel.currentPath = []
                                    viewModel.selectedNode = nil
                                }) {
                                    BreadcrumbItemView(name: rootNode.name, isHighlighted: viewModel.currentPath.isEmpty)
                                }
                                .buttonStyle(.plain)
                                
                                if !viewModel.currentPath.isEmpty {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                
                                ForEach(Array(viewModel.currentPath.enumerated()), id: \.element.id) { index, pathNode in
                                    let isLast = index == viewModel.currentPath.count - 1
                                    Button(action: {
                                        viewModel.navigateBack(to: index)
                                    }) {
                                        BreadcrumbItemView(name: pathNode.name, isHighlighted: isLast)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if !isLast {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
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
                    
                    let currentFolder = viewModel.currentFolderNode ?? rootNode
                    
                    // We use native VSplitView which persists its size during the session
                    // because it is no longer destroyed and recreated by 'if let'
                    VSplitView {
                        TreeMapView(
                            node: currentFolder,
                            selectedNode: viewModel.selectedNode,
                            flatItems: viewModel.showFilesOnly ? viewModel.currentListItems : nil,
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
                        .frame(minHeight: 100)
                        
                        VStack(spacing: 0) {
                            CategoryHistogramView(rootNode: currentFolder)
                            
                            Divider()
                            
                            TopItemsListView(
                                rootNode: currentFolder,
                                selectedNode: viewModel.selectedNode,
                                showFilesOnly: $viewModel.showFilesOnly,
                                onSelect: { node in
                                    viewModel.selectedNode = node
                                },
                                onDoubleTap: { node in
                                    viewModel.drillDown(to: node)
                                },
                                onListUpdated: { items in
                                    viewModel.currentListItems = items
                                }
                            )
                            .frame(minHeight: 150)
                            .background(Color(NSColor.windowBackgroundColor))
                        }
                        .frame(minHeight: 200)
                    }
                }
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
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
                .navigationSplitViewColumnWidth(min: 500, ideal: 800)
                .ignoresSafeArea(.all, edges: .top)
            }
        } detail: {
            // Inspector
            if viewMode == .explorer, let selectedNode = viewModel.selectedNode {
                ItemDetailView(
                    node: selectedNode,
                    onTrash: {
                        Task {
                            await viewModel.trashSelectedNode()
                        }
                    },
                    onReveal: {
                        viewModel.revealSelectedNode()
                    },
                    onDeepClean: {
                        Task {
                            await viewModel.deepCleanSelectedNode()
                        }
                    }
                )
                .navigationSplitViewColumnWidth(min: 250, ideal: CGFloat(inspectorWidth), max: 400)
                .ignoresSafeArea(.all, edges: .top)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newValue in
                    // Automatically save the inspector width when the system NavigationSplitView resizes it
                    if newValue > 250 && newValue < 400 {
                        inspectorWidth = Double(newValue)
                    }
                }
            } else {
                VStack {
                    Image(systemName: "cursorarrow.rays")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(viewMode == .deepClean ? "Deep Clean Active" : "Select an item to view details")
                        .foregroundColor(.secondary)
                        .padding()
                }
                .navigationSplitViewColumnWidth(min: 250, ideal: CGFloat(inspectorWidth), max: 400)
                .ignoresSafeArea(.all, edges: .top)
            }
        }
    }
}

struct BreadcrumbItemView: View {
    let name: String
    let isHighlighted: Bool
    
    var body: some View {
        if isHighlighted {
            Text(name)
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
            Text(name)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
    }
}
