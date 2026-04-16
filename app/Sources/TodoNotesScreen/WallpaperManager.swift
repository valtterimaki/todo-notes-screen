import AppKit

enum WallpaperManager {
    /// Sets the desktop and lock screen wallpaper.
    ///
    /// Uses `desktoppr` for the desktop (writes the Desktop slot in the wallpaper
    /// database via private WallpaperKit APIs, or falls back to NSWorkspace).
    ///
    /// Also directly patches the Idle (lock screen) slots in the wallpaper database
    /// because macOS Sequoia stores them separately and desktoppr only writes Desktop.
    /// On Sequoia the lock screen defaults to the screen-saver provider (Sequoia
    /// Sunrise video) and won't update unless the Idle entries are explicitly rewritten.
    static func set(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }

        // macOS caches wallpapers by URL — copy to a unique timestamped path each time
        // so both desktoppr and NSWorkspace see a "new" URL and reload the image content.
        let source = URL(fileURLWithPath: path)
        let dir = source.deletingLastPathComponent()
        let unique = dir.appendingPathComponent("wallpaper_\(Int(Date().timeIntervalSince1970)).png")

        do {
            try FileManager.default.copyItem(at: source, to: unique)
        } catch {
            applyWallpaper(path: path)
            return
        }

        applyWallpaper(path: unique.path)
        applyLockScreen(path: unique.path)

        let stale = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for file in stale where file.lastPathComponent.hasPrefix("wallpaper_") && file != unique {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Desktop

    private static func applyWallpaper(path: String) {
        if let desktoppr = desktopprPath() {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: desktoppr)
            p.arguments = [path]
            try? p.run()
            p.waitUntilExit()
        } else {
            let url = URL(fileURLWithPath: path)
            for screen in NSScreen.screens {
                try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            }
        }
    }

    // MARK: - Lock screen

    /// Patches the Idle entries in the wallpaper database to use our image instead of
    /// the screen-saver provider, then restarts WallpaperAgent to apply the change.
    private static func applyLockScreen(path: String) {
        let indexURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")

        guard let data = try? Data(contentsOf: indexURL),
              var dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return }

        // Borrow the Configuration blob from an existing Desktop image entry.
        // It contains display-fitting options and is safe to reuse for the Idle slot.
        let configData = desktopConfigData(from: dict)

        let fileURL = "file://\(path)"
        var choice: [String: Any] = [
            "Provider": "com.apple.wallpaper.choice.image",
            "Files": [["relative": fileURL]],
        ]
        if let config = configData { choice["Configuration"] = config }

        let idleEntry: [String: Any] = [
            "Content": ["Choices": [choice]],
            "LastSet": Date(),
        ]

        // AllSpacesAndDisplays.Idle
        if var allSpaces = dict["AllSpacesAndDisplays"] as? [String: Any] {
            var idle = (allSpaces["Idle"] as? [String: Any]) ?? [:]
            idleEntry.forEach { idle[$0] = $1 }
            idle["Type"] = "idle"
            allSpaces["Idle"] = idle
            dict["AllSpacesAndDisplays"] = allSpaces
        }

        // Per-display Idle
        if var displays = dict["Displays"] as? [String: Any] {
            for id in displays.keys {
                if var display = displays[id] as? [String: Any] {
                    var idle = (display["Idle"] as? [String: Any]) ?? [:]
                    idleEntry.forEach { idle[$0] = $1 }
                    display["Idle"] = idle
                    displays[id] = display
                }
            }
            dict["Displays"] = displays
        }

        guard let newData = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else { return }
        try? newData.write(to: indexURL)

        // Restart WallpaperAgent so it picks up the updated Idle entries.
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        kill.arguments = ["WallpaperAgent"]
        try? kill.run()
    }

    private static func desktopConfigData(from dict: [String: Any]) -> Data? {
        guard let displays = dict["Displays"] as? [String: Any] else { return nil }
        for (_, val) in displays {
            guard let display = val as? [String: Any],
                  let choices = (display["Desktop"] as? [String: Any])?["Content"].flatMap({ ($0 as? [String: Any])?["Choices"] as? [[String: Any]] })
            else { continue }
            for choice in choices where choice["Provider"] as? String == "com.apple.wallpaper.choice.image" {
                if let config = choice["Configuration"] as? Data { return config }
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func desktopprPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/desktoppr",  // Apple Silicon
            "/usr/local/bin/desktoppr",     // Intel
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
