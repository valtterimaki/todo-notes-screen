import Foundation
import ServiceManagement

struct TaskListItem: Identifiable, Decodable {
    let id: String
    let title: String
}

@MainActor
class AppState: ObservableObject {
    @Published var isRunning: Bool = true
    @Published var isRefreshing: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var lastError: String? = nil
    @Published var launchAtLogin: Bool = false
    @Published var availableLists: [TaskListItem] = []
    @Published var selectedListName: String = "IMPORTANT"

    private var refreshTimer: Timer?
    private let intervalSeconds: TimeInterval = 2 * 60
    private var lastFingerprint: String? = nil

    private let projectDir: String
    private let pythonPath: String
    private let mainScriptPath: String
    private let imagePath: String
    private let settingsPath: String

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.projectDir = "\(home)/Documents/todo-notes-screen"
        self.pythonPath = "\(home)/Documents/todo-notes-screen/venv/bin/python3"
        self.mainScriptPath = "\(home)/Documents/todo-notes-screen/main.py"
        self.imagePath = "\(home)/.config/todo-notes-screen/current.png"
        self.settingsPath = "\(home)/.config/todo-notes-screen/settings.json"

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.selectedListName = Self.readSelectedList(from: "\(home)/.config/todo-notes-screen/settings.json")

        scheduleTimer()
        Task { await refresh() }
        Task { await fetchAvailableLists() }
    }

    func start() {
        isRunning = true
        scheduleTimer()
        Task { await refresh() }
    }

    func stop() {
        isRunning = false
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil

        let python = pythonPath
        let script = mainScriptPath
        let dir = projectDir
        let image = imagePath
        let knownFingerprint = lastFingerprint

        let result: Result<String?, Error> = await Task.detached(priority: .background) {
            // Step 1: fast fingerprint check — just fetches tasks and hashes them, no render
            var newFingerprint: String? = nil
            let fpProcess = Process()
            fpProcess.executableURL = URL(fileURLWithPath: python)
            fpProcess.arguments = [script, "--fingerprint"]
            fpProcess.currentDirectoryURL = URL(fileURLWithPath: dir)
            let fpPipe = Pipe()
            fpProcess.standardOutput = fpPipe
            fpProcess.standardError = Pipe()
            do {
                try fpProcess.run()
                fpProcess.waitUntilExit()
                let data = fpPipe.fileHandleForReading.readDataToEndOfFile()
                let fingerprint = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if fingerprint == knownFingerprint {
                    return .success(nil) // nil = no change, skip render
                }
                newFingerprint = fingerprint
            } catch {
                // If fingerprint check fails, fall through to full render
            }

            // Step 2: tasks changed (or fingerprint check failed) — do the full render
            let renderProcess = Process()
            renderProcess.executableURL = URL(fileURLWithPath: python)
            renderProcess.arguments = [script, "--no-wallpaper"]
            renderProcess.currentDirectoryURL = URL(fileURLWithPath: dir)
            let pipe = Pipe()
            renderProcess.standardOutput = pipe
            renderProcess.standardError = pipe
            do {
                try renderProcess.run()
                renderProcess.waitUntilExit()
                if renderProcess.terminationStatus == 0 {
                    return .success(newFingerprint ?? "")
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                    return .failure(AppError.pipeline(output.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let newFingerprint):
            if let fp = newFingerprint {
                // Tasks changed — apply wallpaper and record new fingerprint
                lastFingerprint = fp
                WallpaperManager.set(path: image)
                lastUpdated = Date()
            }
            // nil means no change — do nothing
        case .failure(let error):
            lastError = error.localizedDescription
        }

        isRefreshing = false
    }

    func fetchAvailableLists() async {
        let python = pythonPath
        let script = mainScriptPath
        let dir = projectDir

        let result: Result<[TaskListItem], Error> = await Task.detached(priority: .background) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = [script, "--list-task-lists"]
            process.currentDirectoryURL = URL(fileURLWithPath: dir)

            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let items = try JSONDecoder().decode([TaskListItem].self, from: data)
                return .success(items)
            } catch {
                return .failure(error)
            }
        }.value

        if case .success(let lists) = result {
            availableLists = lists
        }
    }

    func selectList(_ name: String) async {
        selectedListName = name
        saveSelectedList(name)
        await refresh()
    }

    func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
                launchAtLogin = false
            } else {
                try SMAppService.mainApp.register()
                launchAtLogin = true
            }
        } catch {
            lastError = "Login item: \(error.localizedDescription)"
        }
    }

    private static func readSelectedList(from path: String) -> String {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["task_list"] as? String else {
            return "IMPORTANT"
        }
        return name
    }

    private func saveSelectedList(_ name: String) {
        let json: [String: Any] = ["task_list": name]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
        }
    }

    private func scheduleTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }
}

enum AppError: LocalizedError {
    case pipeline(String)

    var errorDescription: String? {
        switch self {
        case .pipeline(let msg): return msg
        }
    }
}
