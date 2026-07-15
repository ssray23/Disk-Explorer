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
        case .documents: return .blue
        case .videos: return .indigo
        case .music: return .teal
        case .photos: return .mint
        case .developer: return Color(red: 0.2, green: 0.4, blue: 0.8) // Darker blue
        case .caches: return Color(red: 0.3, green: 0.3, blue: 0.5) // Muted indigo
        case .system: return .gray
        case .mail: return Color(red: 0.1, green: 0.6, blue: 0.8) // Ocean blue
        case .other: return Color(white: 0.4)
        }
    }
}
