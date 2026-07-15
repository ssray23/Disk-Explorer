import Foundation

public struct FileCategories {
    
    public static func classify(url: URL, isDirectory: Bool) -> (category: FileCategory, explanation: String) {
        let path = url.path
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent
        
        // 1. Applications
        if ext == "app" || path.contains("/Applications/") {
            return (.applications, "Installed application. Use 'Deep Clean' to fully remove it and its associated caches/preferences.")
        }
        
        // 2. System
        if path.hasPrefix("/System/") || path.hasPrefix("/sbin/") || path.hasPrefix("/bin/") || path.hasPrefix("/usr/bin/") || path.hasPrefix("/usr/sbin/") || path.hasPrefix("/private/var/vm") || name == ".DS_Store" {
            return (.system, "macOS system files or crucial OS components. Do not delete.")
        }
        
        // 3. Developer / Caches
        if path.contains("DerivedData") {
            return (.developer, "Xcode derived data. Contains build artifacts. Safe to delete — Xcode will regenerate them when you rebuild your project.")
        }
        if path.contains("node_modules") {
            return (.developer, "Node.js package dependencies. Safe to delete — can be restored by running 'npm install' in the project directory.")
        }
        if name == ".git" {
            return (.developer, "Git version control repository. Do not delete unless you want to permanently remove version history for this project.")
        }
        if path.hasPrefix(NSHomeDirectory() + "/Library/Developer/") {
            return (.developer, "Developer tools data (e.g., simulators, device logs). Usually safe to clean if you know what you are doing.")
        }
        
        if path.hasPrefix(NSHomeDirectory() + "/Library/Caches/") || path.hasPrefix("/Library/Caches/") || path.hasPrefix("/private/var/folders/") {
            return (.caches, "Application caches. These are temporary files used to speed up apps. Safe to delete — they will be recreated automatically if needed.")
        }
        
        if path.contains("Homebrew/Cask") || path.contains("Homebrew/downloads") {
            return (.caches, "Homebrew cache files. Safe to delete to free up space. You can also run 'brew cleanup'.")
        }
        
        // 4. Mail & Messages
        if path.hasPrefix(NSHomeDirectory() + "/Library/Mail/") {
            return (.mail, "Email messages and attachments synced with Apple Mail.")
        }
        if path.hasPrefix(NSHomeDirectory() + "/Library/Messages/") {
            return (.mail, "iMessage attachments and history.")
        }
        
        // 5. Media
        let videoExts: Set<String> = ["mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v"]
        if videoExts.contains(ext) || path.hasPrefix(NSHomeDirectory() + "/Movies/") {
            return (.videos, "Video files. These often consume significant space. Consider moving large videos to external storage.")
        }
        
        let audioExts: Set<String> = ["mp3", "m4a", "flac", "wav", "aac", "ogg", "wma"]
        if audioExts.contains(ext) || path.hasPrefix(NSHomeDirectory() + "/Music/") {
            return (.music, "Audio files and music library.")
        }
        
        let photoExts: Set<String> = ["jpg", "jpeg", "png", "heic", "gif", "tiff", "raw", "dng", "cr2", "nef", "arw"]
        if photoExts.contains(ext) || path.hasPrefix(NSHomeDirectory() + "/Pictures/") || path.contains("Photos Library.photoslibrary") {
            return (.photos, "Photo library and image files. Do not delete from inside the Photos Library bundle directly; use the Photos app.")
        }
        
        // 6. Documents
        let docExts: Set<String> = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "txt", "rtf", "csv"]
        if docExts.contains(ext) || path.hasPrefix(NSHomeDirectory() + "/Documents/") || path.hasPrefix(NSHomeDirectory() + "/Desktop/") {
            return (.documents, "Your personal documents and files.")
        }
        
        // 7. Library (Other)
        if path.hasPrefix(NSHomeDirectory() + "/Library/") {
            return (.other, "User library files (Application Support, Preferences, etc.). Be careful deleting files here as it may reset app settings or cause data loss.")
        }
        
        // 8. Default
        if isDirectory {
            return (.other, "Folder containing miscellaneous files.")
        } else {
            return (.other, "Miscellaneous file.")
        }
    }
}
