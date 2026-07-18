# Blazing Fast Performance in Swift & SwiftUI: Best Practices

Based on the optimizations made to the Disk Explorer app, here are four critical best practices for achieving blazing fast performance and low memory footprints in modern Swift and SwiftUI applications.

## 1. Manage Autorelease Pools in High-Volume Loops
When using Apple's Foundation framework, many classes (like `URL`, `FileManager`, and `NSString`) are bridged from legacy Objective-C. Under the hood, these APIs often return objects that are placed into a thread's *autorelease pool*, meaning they won't be cleared from memory until the current event loop finishes.

If you are running a tight loop that processes hundreds of thousands of files or data points, these unreleased objects will rapidly accumulate, leading to gigabyte-sized memory spikes.

**Best Practice:**
Wrap the contents of massive `while` or `for` loops in an `autoreleasepool { }` block. This forces the immediate deallocation of temporary objects at the end of every single iteration, keeping your memory footprint completely flat regardless of how long the loop runs.

```swift
// ❌ BAD: Memory spike!
while let url = enumerator.nextObject() as? URL {
    process(url) // Temporary bridged objects accumulate
}

// ✅ GOOD: Flat memory!
while let url = enumerator.nextObject() as? URL {
    autoreleasepool {
        process(url) // Objects deallocated immediately
    }
}
```

## 2. Know When to Break the "Struct Default" Rule
Swift heavily encourages the use of value-type `structs` to ensure immutability and thread safety. However, if you are building massive, deeply nested data structures (like a file system tree with millions of nodes), structs can become your worst enemy. 

Because structs are value types, modifying a deeply nested child requires creating a full copy of the child, a full copy of its parent, the grandparent, and so on all the way to the root. Furthermore, representing relationships requires dictionary lookups using `UUIDs` instead of memory pointers.

**Best Practice:**
For massively nested or graph-like data structures, use `final class`. This allows you to use direct memory pointers (`weak var parent: Node?`) and `ObjectIdentifier(self)` for blazing fast O(1) hash lookups, drastically reducing memory overhead and CPU copy penalties. 

## 3. Avoid URL Bridging in UI Render Passes
Apple's `URL` type is a hefty, complex structure that conforms to standard RFCs and parses protocols, authorities, and paths. Repeatedly creating or mutating `URL` objects (e.g., `url.appendingPathComponent(name)`) on the main thread inside UI loops can cause severe CPU bottlenecks and frame drops due to Objective-C bridging overhead.

**Best Practice:**
If you only need to build and display file paths in the UI, avoid `URL` completely. Rely on pure Swift `String` arrays to collect path components, and use `.joined(separator: "/")` to concatenate them. Pure Swift string operations are phenomenally faster than bridging to Foundation's `URL`.

```swift
// ❌ BAD: Very slow when run 10,000 times
var url = parent.path
url = url.appendingPathComponent(childName)

// ✅ GOOD: Lightning fast
let pathString = parent.pathString + "/" + childName
```

## 4. Ditch `List` for Large, Selectable Data in macOS
On macOS, SwiftUI's native `List` view is silently bridged to AppKit's `NSTableView`. While this is great for getting native behaviors out of the box, it is notoriously heavy. When you manually change state variables that affect the list (like `selectedNode`), `NSTableView` can trigger expensive layout invalidation passes across every cell to check for height changes—especially disastrous if your rows use `GeometryReader`.

**Best Practice:**
If you need maximum rendering speed for a highly customized list of items, drop `List` and use a pure SwiftUI `ScrollView` combined with a `LazyVStack`. 

To achieve maximum efficiency, extract your row into its own standalone `View` struct and apply the `.equatable()` modifier. By defining `static func ==`, you explicitly tell SwiftUI's diffing engine to completely skip evaluating the layout of rows that haven't changed.

```swift
// ❌ BAD: Heavy NSTableView bridging overhead on selection changes
List(items) { item in
    MyRow(item: item)
        .background(item == selected ? Color.blue : Color.clear)
}

// ✅ GOOD: Pure SwiftUI, instant diffing, 0-cost unselected rows
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            MyRow(item: item, isSelected: item == selected)
                .equatable()
        }
    }
}
```

## 5. Never Block the MainActor (The "Spinning Beach Ball" Rule)
In Swift concurrency, properties and functions marked with `@MainActor` or executing within SwiftUI views run entirely on the UI thread. Calling synchronous blocking APIs—like `Process()` shell commands, AppleScript executions (`NSAppleScript`), or intensive `FileManager` deletions—will completely freeze your UI loop until they return, causing macOS to display the dreaded spinning beach ball.

Even if your function is marked `async`, calling a blocking API inside it will still stall the thread it runs on.

**Best Practice:**
Always offload synchronous, computationally heavy, or blocking I/O work to a background thread using `Task.detached { ... }`. When crossing isolation boundaries (like passing arrays of models into the detached task), ensure your data models conform to the `Sendable` protocol so the Swift 6 compiler can statically guarantee your code is free of data races.

```swift
// ❌ BAD: Blocks the UI thread! Beachball guaranteed.
@MainActor
func cleanFiles() async {
    isCleaning = true // UI updates
    let script = NSAppleScript(source: "do shell script...")
    script?.executeAndReturnError(nil) // STOPS the entire app!
    isCleaning = false
}

// ✅ GOOD: Flawless responsive UI
@MainActor
func cleanFiles() async {
    isCleaning = true
    
    // Pass Sendable data into a background thread
    await Task.detached {
        let script = NSAppleScript(source: "do shell script...")
        script?.executeAndReturnError(nil) // Runs safely in the background
    }.value
    
    isCleaning = false
}
```

## 6. Eliminate Selection Delay in ScrollViews/Lists (Manual Double-Tap Timing)
By default, SwiftUI's gesture handlers (such as placing a double-tap gesture alongside a single-tap gesture, or using standard interactive selection lists) introduce a **350ms delay** on every single tap. The system waits to verify if the user will perform a second tap (to trigger a double-click) before running the single-click action. This makes list row selections feel sluggish and delayed.

**Best Practice:**
Implement a manual double-tap detection system within a single, standard tap gesture using a timestamp log. This allows you to run selection logic **instantly** (0ms latency) on the initial tap. If a second tap arrives within a tight window (e.g., `< 0.3` seconds) on the same element, execute the double-tap action (e.g., opening a folder).

```swift
// ❌ BAD: Delays single taps by 350ms to check for double-taps
RowView(item)
    .onTapGesture { select(item) }
    .onTapGesture(count: 2) { open(item) }

// ✅ GOOD: Single clicks are instant (0ms latency), double clicks traverse dynamically
RowView(item)
    .onTapGesture {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.3 && lastTapItem == item {
            open(item)
            lastTapTime = Date.distantPast
        } else {
            select(item) // Trigger selection instantly!
            lastTapItem = item
            lastTapTime = now
        }
    }
```

