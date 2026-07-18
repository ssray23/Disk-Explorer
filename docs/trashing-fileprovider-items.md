# Trashing Files and Folders Safely

Disk Explorer moves normal files and folders to the macOS Trash through Finder. This is
deliberate: Finder owns the system-integrated trash workflow and correctly participates in
File Provider coordination for iCloud Drive and other cloud-backed locations.

## The failure we observed

The original implementation called `FileManager.default.trashItem(at:resultingItemURL:)`
directly. The UI action was wired correctly: diagnostic logging showed that
`ScanViewModel.trashSelectedNode()` entered `CleanupService.moveToTrash(url:)`. The call then
stopped making progress inside `trashItem`.

Process stack samples showed multiple blocked threads below the Foundation trash API in the
File Provider trash path (`fp_trashItemAtURL`). The affected items were in iCloud-backed
folders. Moving the same items to Trash from Finder continued to work.

Wrapping `trashItem` in an `NSFileCoordinator` delete accessor was also tested. That version
blocked while waiting for File Provider coordination before the accessor could complete. It
therefore did not provide a reliable application-level fix for the observed failure.

This was not a Gatekeeper or notarization failure. Notarization affects whether macOS trusts
and launches an application. The blocked code was executing after launch, inside File
Provider's filesystem coordination path.

## Implemented design

The normal trash path now has the following flow:

1. `ItemDetailView` invokes the trash action.
2. `ScanViewModel.trashSelectedNode()` sets `isProcessing`, calls the cleanup service, and
   updates the in-memory file tree only after the operation succeeds.
3. `CleanupService.moveToTrash(url:)` submits the target URL to a dedicated
   `FinderTrashOperations` instance.
4. `FinderTrashOperations` executes this Finder Apple Event on a private serial queue:

   ```applescript
   tell application "Finder"
       delete POSIX file "/path/to/item"
   end tell
   ```

5. Finder performs the Trash operation using its native File Provider-aware implementation.
6. A checked throwing continuation returns success or the Finder AppleScript error to Swift
   concurrency.

The serial queue is important because `NSAppleScript.executeAndReturnError` is synchronous.
Running it away from the main actor prevents Finder or File Provider latency from freezing the
SwiftUI interface. Serial execution also prevents repeated trash requests from competing with
one another.

Paths are encoded as AppleScript string literals rather than shell commands. Backslashes and
double quotes are escaped before interpolation. The ordinary Finder path therefore does not
pass user-selected filenames through a shell.

## UI behavior

While a trash operation is active, the inspector:

- displays `Moving to Trash...` with a progress indicator;
- disables Move to Trash, Deep Clean, Reveal in Finder, and web search actions; and
- prevents repeated clicks from queuing duplicate requests.

On success, the selected node is removed from the displayed scan tree. On failure, the app
keeps the node and displays the propagated error.

## macOS permissions

Finder control uses Apple Events. The app bundle includes `NSAppleEventsUsageDescription` in
`Info.plist`, so macOS can explain the request. On the first trash operation, macOS may ask
whether Disk Explorer may control Finder. The user must allow this for the Finder-backed path
to work.

If access was denied, enable it under **System Settings > Privacy & Security > Automation** by
allowing Disk Explorer to control Finder. AppleScript error `-1743` normally indicates that
Apple Event authorization is missing.

Full Disk Access and Automation are separate permissions. Full Disk Access helps the scanner
read protected locations; it does not grant permission to control Finder.

## iCloud and other File Provider locations

`~/Library/Mobile Documents/com~apple~CloudDocs` is a live iCloud Drive location, not an
isolated local snapshot. Trashing an item there through Finder removes it from the local iCloud
view and synchronizes that deletion through iCloud, just as a manual Finder trash operation
would.

Source code may live in iCloud, but the runnable app should not. `build.sh` installs the signed
bundle at `~/Applications/Disk Explorer.app`. Always launch that copy, rather than an app bundle
inside the cloud-backed source folder. The Swift Package `.build` directory still contains
temporary compiler output and is ignored by Git.

Cloud-only items may take time to materialize or coordinate. The UI remains responsive while
Finder completes or rejects the request.

## Diagnostics

Disk Explorer records the trash lifecycle in:

```text
~/Library/Application Support/DiskExplorer/debug.log
```

Useful entries include:

```text
[ScanViewModel] trashSelectedNode() started
[CleanupService] Asking Finder to move item to Trash...
[CleanupService] Finder trash operation succeeded...
```

If the first two appear without a success or failure entry, sample both Disk Explorer and
Finder and check the current File Provider state. If an error appears, verify Automation access
first, then confirm that Finder can trash the same item manually.

## Scope and recovery semantics

This document describes the normal **Move to Trash** action and the trashing portion of
application Deep Clean. The separate Deep Clean dashboard also contains explicitly labelled
maintenance actions that permanently remove disposable caches; those do not all use this
Finder path.

Finder may rename a trashed item to resolve a name collision. The Apple Event does not return
the final Trash URL, so `CleanupService` returns the original URL as its success marker. Files
remain recoverable from Trash until Trash is emptied.
