import SwiftUI

public enum FileCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case applications = "Applications"
    case documents = "Documents"
    case videos = "Videos"
    case music = "Music/Audio"
    case photos = "Photos"
    case developer = "Developer"
    case caches = "Caches"
    case system = "System"
    case mail = "Mail & Messages"
    case other = "Other"
    
    public var color: Color {
        switch self {
        case .applications: return .cyan
        case .documents: return .yellow
        case .videos: return .indigo
        case .music: return .teal
        case .photos: return .mint
        case .developer: return .purple // Darker blue replaced with purple
        case .caches: return Color(red: 0.3, green: 0.3, blue: 0.5) // Muted indigo
        case .system: return .red
        case .mail: return .pink // Ocean blue replaced with pink
        case .other: return .orange
        }
    }
}
