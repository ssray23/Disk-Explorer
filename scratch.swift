import Foundation

let path1 = URL(fileURLWithPath: "/Users/suddharay")
print(path1.path, "->", path1.resolvingSymlinksInPath().path)

let path2 = URL(fileURLWithPath: "/Applications")
print(path2.path, "->", path2.resolvingSymlinksInPath().path)

