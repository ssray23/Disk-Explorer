import SwiftUI
import UniformTypeIdentifiers

public struct CustomFolderPicker: View {
    let onCancel: () -> Void
    let onSelect: (URL) -> Void
    
    @State private var currentURL: URL = URL(fileURLWithPath: NSHomeDirectory())
    @State private var subfolders: [URL] = []
    @State private var selectedSubfolder: URL? = nil
    @State private var searchPattern: String = ""
    @State private var hoverLocation: String? = nil
    @State private var hoverFolder: URL? = nil
    @State private var lastTapTime = Date.distantPast
    @State private var lastTapFolder: URL? = nil
    
    // Quick access system locations
    private var systemLocations: [(name: String, icon: String, url: URL)] {
        [
            ("Home", "house.fill", URL(fileURLWithPath: NSHomeDirectory())),
            ("Desktop", "desktopcomputer", URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")),
            ("Documents", "doc.text.fill", URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")),
            ("Downloads", "arrow.down.circle.fill", URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")),
            ("Root HD", "internaldrive", URL(fileURLWithPath: "/"))
        ]
    }
    
    // Dynamically discover cloud storage locations
    private var cloudLocations: [(name: String, icon: String, url: URL)] {
        var locations: [(name: String, icon: String, url: URL)] = []
        
        // 1. iCloud Drive
        let iCloudURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: iCloudURL.path) {
            locations.append(("iCloud Drive", "cloud.fill", iCloudURL))
        }
        
        // 2. Cloud Storage Providers (OneDrive, Google Drive, Dropbox, Box)
        let cloudStorageURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/CloudStorage")
        if let contents = try? FileManager.default.contentsOfDirectory(at: cloudStorageURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for url in contents {
                let name = url.lastPathComponent
                var icon = "cloud.fill"
                
                // Beautiful custom icons based on provider name
                if name.localizedCaseInsensitiveContains("onedrive") {
                    icon = "cloud.rainbow.half.fill"
                } else if name.localizedCaseInsensitiveContains("dropbox") {
                    icon = "archivebox.fill"
                } else if name.localizedCaseInsensitiveContains("google") {
                    icon = "arrow.triangle.2.circlepath.circle.fill"
                } else if name.localizedCaseInsensitiveContains("box") {
                    icon = "shippingbox.fill"
                }
                
                // Format provider name to be user friendly
                let displayName = name
                    .replacingOccurrences(of: "OneDrive-Personal", with: "OneDrive")
                    .replacingOccurrences(of: "OneDrive-", with: "OneDrive (")
                    .appending(name.localizedCaseInsensitiveContains("OneDrive-") && name != "OneDrive-Personal" ? ")" : "")
                
                locations.append((displayName, icon, url))
            }
        }
        
        return locations
    }
    
    // Dynamically discover external volumes
    private var externalLocations: [(name: String, icon: String, url: URL)] {
        var locations: [(name: String, icon: String, url: URL)] = []
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        if let contents = try? FileManager.default.contentsOfDirectory(at: volumesURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for url in contents {
                if url.lastPathComponent != "Macintosh HD" {
                    locations.append((url.lastPathComponent, "externaldrive.fill", url))
                }
            }
        }
        return locations
    }
    
    public init(onCancel: @escaping () -> Void, onSelect: @escaping (URL) -> Void) {
        self.onCancel = onCancel
        self.onSelect = onSelect
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Sidebar for quick locations
            VStack(alignment: .leading, spacing: 6) {
                // Drag area spacer to allow dragging the window from the top sidebar space
                Color.clear
                    .frame(height: 12)
                
                // System section
                sidebarHeader(title: "Favorites")
                ForEach(systemLocations, id: \.name) { loc in
                    sidebarItem(name: loc.name, icon: loc.icon, url: loc.url, color: .blue)
                }
                
                // Cloud Storage section
                let clouds = cloudLocations
                if !clouds.isEmpty {
                    sidebarHeader(title: "Cloud Storage")
                        .padding(.top, 12)
                    ForEach(clouds, id: \.name) { loc in
                        sidebarItem(name: loc.name, icon: loc.icon, url: loc.url, color: .cyan)
                    }
                }
                
                // External Volumes section
                let externals = externalLocations
                if !externals.isEmpty {
                    sidebarHeader(title: "Devices")
                        .padding(.top, 12)
                    ForEach(externals, id: \.name) { loc in
                        sidebarItem(name: loc.name, icon: loc.icon, url: loc.url, color: .orange)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(width: 210)
            .background(.regularMaterial)
            
            // Main folder browser area
            VStack(spacing: 0) {
                // Path Bar & Search Bar
                HStack(spacing: 12) {
                    // Back button
                    Button(action: {
                        if currentURL.path != "/" {
                            currentURL = currentURL.deletingLastPathComponent()
                            loadFolders()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(currentURL.path == "/" ? .secondary : .primary)
                            .padding(8)
                            .background(Color.secondary.opacity(currentURL.path == "/" ? 0.03 : 0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(currentURL.path == "/")
                    .buttonStyle(.plain)
                    
                    // Path Display (interactive breadcrumbs)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            let components = pathComponents(for: currentURL)
                            ForEach(0..<components.count, id: \.self) { index in
                                let comp = components[index]
                                Button(action: {
                                    currentURL = comp.url
                                    loadFolders()
                                }) {
                                    Text(comp.name)
                                        .font(.system(size: 13, weight: index == components.count - 1 ? .semibold : .regular))
                                        .foregroundColor(index == components.count - 1 ? .primary : .secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(index == components.count - 1 ? 0.12 : 0.04))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                
                                if index < components.count - 1 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Search box
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        TextField("Filter Folders", text: $searchPattern)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .frame(width: 140)
                        if !searchPattern.isEmpty {
                            Button(action: { searchPattern = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                }
                .padding(.leading, 16) // Align path bar content next to vertical divider
                .padding(.trailing, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                Divider()
                
                // Folder List
                let filteredFolders = subfolders.filter { url in
                    searchPattern.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(searchPattern)
                }
                
                if filteredFolders.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: searchPattern.isEmpty ? "folder.badge.questionmark" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(searchPattern.isEmpty ? "No accessible folders here." : "No matching folders found.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredFolders, id: \.self) { url in
                                let isRowSelected = selectedSubfolder == url
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(isRowSelected ? .white : .blue.opacity(0.85))
                                    
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 13, weight: isRowSelected ? .semibold : .regular))
                                        .foregroundColor(isRowSelected ? .white : .primary)
                                    
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isRowSelected ? Color.accentColor : (hoverFolder == url ? Color.secondary.opacity(0.06) : Color.clear))
                                )
                                .foregroundColor(isRowSelected ? .white : .primary)
                                .onHover { isHovered in
                                    hoverFolder = isHovered ? url : nil
                                }
                                .onTapGesture {
                                    let now = Date()
                                    if now.timeIntervalSince(lastTapTime) < 0.3 && lastTapFolder == url {
                                        // Double tap: open folder
                                        currentURL = url
                                        loadFolders()
                                        lastTapTime = Date.distantPast
                                    } else {
                                        // Single tap: select immediately with zero delay
                                        selectedSubfolder = url
                                        lastTapFolder = url
                                        lastTapTime = now
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                }
                
                Divider()
                
                // Action Buttons Footer
                HStack(spacing: 14) {
                    // Selected directory path preview
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundColor(.secondary)
                        Text(selectedSubfolder?.path ?? currentURL.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: 350, alignment: .leading)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Scan Current") {
                        onSelect(currentURL)
                    }
                    .buttonStyle(.bordered)
                    
                    if let selected = selectedSubfolder {
                        Button("Scan Selected") {
                            onSelect(selected)
                        }
                        .buttonStyle(.borderedProminent)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 800, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .onAppear {
            loadFolders()
        }
    }
    
    // Sidebar Header Helper
    private func sidebarHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
    
    // Sidebar Item Helper
    private func sidebarItem(name: String, icon: String, url: URL, color: Color) -> some View {
        let isSelected = currentURL.path == url.path
        return Button(action: {
            currentURL = url
            loadFolders()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 18)
                
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : (hoverLocation == name ? Color.secondary.opacity(0.08) : Color.clear))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoverLocation = isHovered ? name : nil
        }
    }
    
    private func loadFolders() {
        selectedSubfolder = nil
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: currentURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            subfolders = contents.filter { url in
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return resourceValues?.isDirectory ?? false
            }.sorted { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            subfolders = []
        }
    }
    
    // Deconstructs URL path into interactive breadcrumb components
    private func pathComponents(for url: URL) -> [(name: String, url: URL)] {
        var result: [(name: String, url: URL)] = []
        var temp = url.standardizedFileURL
        
        while temp.path != "/" {
            result.insert((temp.lastPathComponent, temp), at: 0)
            temp = temp.deletingLastPathComponent()
        }
        result.insert(("Root HD", URL(fileURLWithPath: "/")), at: 0)
        return result
    }
}

// Controller to present CustomFolderPicker in a separate movable, resizable glassmorphic window
@MainActor
public class CustomFolderPickerWindow {
    private static var currentWindow: NSWindow?
    
    public static func show(onSelect: @escaping (URL) -> Void) {
        if let window = currentWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let picker = CustomFolderPicker(
            onCancel: {
                close()
            },
            onSelect: { url in
                onSelect(url)
                close()
            }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Select Folder to Scan"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true // Allows dragging from any background space
        window.isReleasedWhenClosed = false
        window.hasShadow = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarSeparatorStyle = .none
        
        // Use delegate to nil-out reference when closed safely under strict concurrency
        window.delegate = WindowDelegate.shared
        
        let hostingView = NSHostingView(rootView: picker)
        window.contentView = hostingView
        
        self.currentWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public static func close() {
        currentWindow?.orderOut(nil)
        currentWindow = nil
    }
    
    @MainActor
    private class WindowDelegate: NSObject, NSWindowDelegate {
        static let shared = WindowDelegate()
        
        func windowWillClose(_ notification: Notification) {
            Task { @MainActor in
                CustomFolderPickerWindow.currentWindow = nil
            }
        }
    }
}
