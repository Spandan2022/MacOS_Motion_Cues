// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Offers to move the app into Applications when it's opened straight from the DMG, from
/// Downloads, or from a quarantined location macOS has translocated. Otherwise the app keeps
/// running from the disk image: ejecting it quits the app and Open at Login breaks.
enum AppMover {
    /// Returns true when the app is moving and about to quit, so launch should stop here.
    static func offerMoveIfNeeded() -> Bool {
        let source = Bundle.main.bundleURL
        guard needsMove(source) else { return false }

        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Move Motion Cues to your Applications folder?"
        a.informativeText = isOnDiskImage(source)
            ? "It's running from the disk image, so it will quit when the image is ejected and can't open at login."
            : "It's running from \(source.deletingLastPathComponent().lastPathComponent), so it can't reliably open at login."
        a.addButton(withTitle: "Move to Applications")
        a.addButton(withTitle: "Not Now")
        guard a.runModal() == .alertFirstButtonReturn else { return false }

        do {
            let destination = try install(source)
            relaunch(destination, eject: isOnDiskImage(source) ? volume(of: source) : nil)
            return true
        } catch {
            let e = NSAlert()
            e.messageText = "Couldn't move Motion Cues"
            e.informativeText = "\(error.localizedDescription)\n\nYou can drag it into Applications yourself."
            e.runModal()
            return false
        }
    }

    // MARK: - Where the app is running from

    static func needsMove(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/") { return false }
        return isOnDiskImage(url)
            || path.contains("/AppTranslocation/")
            || path.hasPrefix(home + "/Downloads/")
    }

    private static func isOnDiskImage(_ url: URL) -> Bool {
        let readOnly = (try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) ?? false
        return url.path.hasPrefix("/Volumes/") && readOnly
    }

    private static func volume(of url: URL) -> URL? {
        try? url.resourceValues(forKeys: [.volumeURLKey]).volume
    }

    // MARK: - Moving

    /// Copies the app into Applications, replacing an older copy, and returns the new location.
    private static func install(_ source: URL) throws -> URL {
        let fm = FileManager.default
        let name = source.lastPathComponent
        let userApps = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        // Replace an existing copy in ~/Applications (where start.sh installs) instead of
        // leaving two; otherwise prefer /Applications when it's writable.
        let destination: URL
        if fm.fileExists(atPath: userApps.appendingPathComponent(name).path) {
            destination = userApps.appendingPathComponent(name)
        } else if fm.isWritableFile(atPath: "/Applications") {
            destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(name)
        } else {
            try fm.createDirectory(at: userApps, withIntermediateDirectories: true)
            destination = userApps.appendingPathComponent(name)
        }

        if fm.fileExists(atPath: destination.path) {
            quitOtherInstances(at: destination)
            try fm.trashItem(at: destination, resultingItemURL: nil)
        }
        // ditto keeps the code signature, extended attributes and permissions intact.
        try run("/usr/bin/ditto", [source.path, destination.path])
        // The user already opened this notarized build, so skip a second Gatekeeper prompt.
        try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", destination.path])
        return destination
    }

    private static func quitOtherInstances(at url: URL) {
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != me && $0.bundleURL?.standardizedFileURL == url.standardizedFileURL }
        others.forEach { $0.terminate() }
        let deadline = Date().addingTimeInterval(3)
        while others.contains(where: { !$0.isTerminated }) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        others.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
    }

    /// Opens the new copy once this process has exited, then ejects the disk image.
    private static func relaunch(_ app: URL, eject volume: URL?) {
        let pid = ProcessInfo.processInfo.processIdentifier
        var script = "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open \"$1\""
        if volume != nil { script += "; /bin/sleep 1; /usr/bin/hdiutil detach \"$2\" -quiet" }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, "sh", app.path] + (volume.map { [$0.path] } ?? [])
        try? p.run()
        NSApp.terminate(nil)
    }

    private static func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw NSError(domain: "AppMover", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(URL(fileURLWithPath: tool).lastPathComponent) failed (\(p.terminationStatus))."])
        }
    }
}
