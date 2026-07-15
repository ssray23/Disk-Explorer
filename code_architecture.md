# Code Architecture Diagram

Here is a pictorial guide showing how all the source files in the Disk Explorer app are linked and depend on each other. It uses the same color palette as the original technical outline.

```mermaid
graph TD
    %% Define Layers
    subgraph App Layer
        App[DiskExplorer.swift]
    end

    subgraph Views
        Main[MainView.swift]
        SysView[SystemInfoView.swift]
        Tree[TreeMapView.swift]
        List[TopItemsListView.swift]
        Detail[ItemDetailView.swift]
    end

    subgraph View Models
        VM[ScanViewModel.swift]
    end

    subgraph Services
        ScanSvc[DiskScanner.swift]
        SysSvc[SystemInfoService.swift]
        CleanSvc[CleanupService.swift]
    end

    subgraph Utilities
        CatUtil[FileCategories.swift]
        Fmt[ByteFormatter.swift]
    end

    subgraph Models
        Node[FileNode.swift]
        Cat[FileCategory.swift]
        Info[SystemInfo.swift]
    end

    %% Define Connections
    App --> Main
    
    Main --> VM
    Main --> SysView
    Main --> Tree
    Main --> List
    Main --> Detail
    
    VM --> ScanSvc
    VM --> SysSvc
    VM --> CleanSvc
    VM -.-> Node
    VM -.-> Info
    
    Tree --> Fmt
    Tree -.-> Node
    
    List --> Fmt
    List -.-> Node
    
    Detail --> Fmt
    Detail -.-> Node
    
    SysView --> Fmt
    SysView -.-> Info
    
    ScanSvc --> CatUtil
    ScanSvc --> Node
    
    SysSvc --> Info
    
    CatUtil --> Cat
    Node --> Cat

    %% Styling to match the requested minimalist/dark theme
    classDef appLayer fill:#1a1a2e,color:#e0e0ff,stroke:#333,stroke-width:2px;
    classDef views fill:#16213e,color:#e0e0ff,stroke:#333,stroke-width:1px;
    classDef viewmodels fill:#0f3460,color:#e0e0ff,stroke:#333,stroke-width:2px;
    classDef services fill:#533483,color:#e0e0ff,stroke:#333,stroke-width:1px;
    classDef utilities fill:#e94560,color:#ffffff,stroke:#333,stroke-width:1px;
    classDef models fill:#ffffff,color:#000000,stroke:#333,stroke-width:1px;
    
    class App appLayer;
    class Main,SysView,Tree,List,Detail views;
    class VM viewmodels;
    class ScanSvc,SysSvc,CleanSvc services;
    class CatUtil,Fmt utilities;
    class Node,Cat,Info models;
```
