# Disk Explorer Code Architecture

This document provides a detailed breakdown of every source file in the Disk Explorer codebase and explains its role in the application architecture.

## 1. App Layer
- **`DiskExplorer.swift`**: The main entry point of the app. It conforms to the `App` protocol and sets up the primary `WindowGroup`. It also injects the global configuration, such as `.windowStyle(.hiddenTitleBar)` to enable the custom, modern macOS title bar look.

## 2. Models
The models are the core data structures passed around the app, designed to be lightweight and strictly conform to `Sendable` where necessary for safe concurrency.
- **`FileNode.swift`**: The foundational tree data structure representing a file, folder, or alias. It holds properties like `id`, `name`, `size`, `isDirectory`, `isAlias`, and an array of `children`. It conforms to `Identifiable` and `Hashable` for SwiftUI list rendering and diffing.
- **`FileCategory.swift`**: An enum defining the high-level categories a file can belong to (e.g., Documents, Photos, Developer, System, Trash). It maps categories to specific vibrant SwiftUI `Color` values for the histograms and Tree Map.
- **`SystemInfo.swift`**: A simple data model that holds the macroscopic physical drive statistics, such as total volume capacity, used space, free space, and localized device descriptions like the Mac model and macOS version.

## 3. Utilities
Helper files that perform isolated, stateless transformations.
- **`ByteFormatter.swift`**: Provides static formatting functions that convert raw `Int64` byte counts into human-readable strings (e.g., "KB", "MB", "GB", "TB") using native macOS formatters.
- **`FileCategories.swift`**: A utility manager containing the heuristic logic and file extension dictionaries to map arbitrary file paths to their corresponding `FileCategory`.

## 4. Services
Services handle the heavy-lifting, file-system I/O, and asynchronous tasks, offloading work from the main thread.
- **`DiskScanner.swift`**: Contains the highly parallelized core scanning engine. It uses `FileManager.enumerator` to crawl the disk, safely bypassing macOS firmlinks by resolving physical URLs. It builds the hierarchical `FileNode` tree recursively.
- **`SystemInfoService.swift`**: Interfaces with the lower-level Darwin layers and `URLResourceValues` to fetch the overall Macintosh HD volume metrics, memory size, CPU type, and OS version.
- **`CleanupService`**: Securely handles the deletion of files and folders using `NSWorkspace` to bypass the sandbox, moving items to the `.Trash` directory.

## 5. ViewModels
ViewModels act as the bridge between the Services and the Views, holding `@Published` state that drives the SwiftUI interfaces.
- **`ScanViewModel.swift`**: The central brain of the app. It coordinates `DiskScanner` to load the filesystem, tracks the currently selected folder via `currentPath` (used for breadcrumbs), stores the top files array (`currentListItems`), and manages the state of the "Files Only" vs "Folders Only" toggle.
- **`DeepCleanViewModel.swift`**: A specialized, isolated ViewModel specifically for the "Deep Clean" dashboard. It safely calculates sizes of specific predefined paths (like Xcode Derived Data, Caches, and the Trash) and manages their deletion lifecycle.

## 6. Views
The declarative SwiftUI presentation layer.
- **`MainView.swift`**: The structural root view using a `NavigationSplitView`. It orchestrates the sidebar, the main content area (routing between the deep clean dashboard and the main explorer), and the right-hand inspector.
- **`SystemInfoView.swift`**: Renders the macroscopic system details and the main capacity progress bar shown at the top of the sidebar.
- **`TreeMapView.swift`**: Implements a sophisticated "squarified treemap" algorithm. It recursively slices a `GeometryReader` canvas into proportional colored blocks based on the relative byte sizes of the provided `FileNode` items. It dynamically morphs its layout between structural folders and flat files depending on the active state.
- **`TopItemsListView.swift`**: Displays the "Largest Items" list. It utilizes an asynchronous, iterative stack-based traversal (to prevent stack overflows on massive drives) to crawl the provided tree and bubble up the top 150 largest files or folders dynamically.
- **`CategoryHistogramView.swift`**: Renders the stacked bar chart breakdown (e.g., Photos, Documents) for whatever folder you are currently viewing. It calculates this breakdown on the fly via a background task triggered by folder navigation.
- **`ItemDetailView.swift`**: The inspector panel anchored to the right side of the screen. It displays detailed metadata for the currently selected file and houses the "Reveal in Finder", "Search Google", and "Move to Trash" action buttons in a rigid bottom footer.
- **`DeepCleanView.swift`**: The dedicated, isolated dashboard view for scanning and cleaning system caches, logs, and derived data safely.
- **`SettingsView.swift`**: The app's preferences window, providing instructions and status indicators for granting macOS Full Disk Access.

## 7. Managers
- **`PermissionsManager.swift`**: A singleton manager tasked with verifying if the application currently has the elevated "Full Disk Access" macOS privacy permissions required to scan the entire root drive.
