import Testing
import Foundation
@testable import DiskExplorer

@Suite("Pure Functions")
struct PureFunctionTests {
    @Test("ByteFormatter correctly formats byte sizes")
    func testByteFormatter() {
        #expect(ByteFormatter.format(1_500_000) == "1.5 MB")
        #expect(ByteFormatter.format(1_500_000_000) == "1.5 GB")
    }

    @Test("FileCategories correctly classifies known paths")
    func testFileCategories() {
        let appURL = URL(fileURLWithPath: "/Applications/Safari.app")
        let classification = FileCategories.classify(url: appURL, isDirectory: true)
        #expect(classification.category == .applications)
        
        let nodeURL = URL(fileURLWithPath: "/Users/test/node_modules")
        let devClassification = FileCategories.classify(url: nodeURL, isDirectory: true)
        #expect(devClassification.category == .developer)
    }
}

@Suite("DiskScanner Behavior")
struct DiskScannerTests {
    @Test("DiskScanner cancellation halts scan and returns nil")
    func testScannerCancellation() async {
        let scanner = DiskScanner()
        let testURL = URL(fileURLWithPath: NSHomeDirectory())
        
        // Cancel immediately
        scanner.cancel()
        
        let result = await withCheckedContinuation { continuation in
            scanner.scan(url: testURL, updateHandler: { _ in }, completionHandler: { node in
                continuation.resume(returning: node)
            })
        }
        
        #expect(result == nil)
    }
}
