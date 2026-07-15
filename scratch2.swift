import Foundation

let url = URL(fileURLWithPath: "/System/Volumes/Data/Applications")
let keys: [URLResourceKey] = [.isDirectoryKey]
if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsSubdirectoryDescendants]) {
    for case let fileURL as URL in enumerator {
        print("URL path:", fileURL.path)
        print("Resolved:", fileURL.resolvingSymlinksInPath().path)
        break
    }
}

let url2 = URL(fileURLWithPath: "/System/Volumes/Data/Users")
if let enumerator = FileManager.default.enumerator(at: url2, includingPropertiesForKeys: keys, options: [.skipsSubdirectoryDescendants]) {
    for case let fileURL as URL in enumerator {
        if fileURL.path.contains("suddharay") {
            print("URL path:", fileURL.path)
            print("Resolved:", fileURL.resolvingSymlinksInPath().path)
            break
        }
    }
}

