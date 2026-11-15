import AppKit
import SambatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusBar: StatusBarController!
    private var settingsWindow: SettingsWindowController?
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App Nap can hold a menu bar app's timers for minutes; the date must flip right at Nepal midnight.
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep],
                                                         reason: "Keep the Nepali date in the menu bar on time")
        model = AppModel()
        statusBar = StatusBarController(model: model)
        model.openSettings = { [weak self] tab in self?.showSettings(tab) }

        #if DEBUG
        if let dir = ProcessInfo.processInfo.environment["PATRO_SNAPSHOT_DIR"] {
            runSnapshots(to: URL(fileURLWithPath: dir))
            return
        }
        #endif
        if !UserDefaults.standard.bool(forKey: "didShowWelcome") {
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.statusBar.openPopover(page: .calendar)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar.openPopover()
        return false
    }

    private func showSettings(_ tab: SettingsTab) {
        if settingsWindow == nil { settingsWindow = SettingsWindowController(model: model) }
        settingsWindow?.show(tab)
    }

    #if DEBUG
    /// Renders the popover and settings in several configurations to PNGs, then quits.
    private func runSnapshots(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = model.settings
        let configs: [(String, AppearanceMode, Language, Language, AccentChoice)] = [
            ("light", .light, .english, .nepali, .system),
            ("dark", .dark, .english, .nepali, .system),
            ("light-en", .light, .english, .english, .blue),
            ("dark-ne", .dark, .nepali, .nepali, .marigold),
        ]
        var steps: [() -> Void] = []
        for (name, appearance, ui, cal, accent) in configs {
            steps.append { [weak self] in
                guard let self else { return }
                self.model.settings.appearance = appearance
                NSApp.appearance = appearance.nsAppearance
                self.model.snapshotBackground = true
                self.model.settings.language = ui
                self.model.settings.calendarLanguage = cal
                self.model.settings.accent = accent
                self.model.selectedJDN = name.hasPrefix("dark") ? self.model.todayJDN + 7 : nil
            }
            steps += statusBar.snapshotSteps(to: dir, prefix: name)
            if name == "light" || name == "dark" {
                steps.append { [weak self] in self?.statusBar.closePopover() }
                steps.append { [weak self] in
                    guard let self else { return }
                    if self.settingsWindow == nil { self.settingsWindow = SettingsWindowController(model: self.model) }
                }
                steps += [{}] // let the window build
                steps.append(contentsOf: lazySettingsSteps(dir: dir, prefix: name))
                steps.append { [weak self] in self?.settingsWindow?.close() }
            }
        }
        steps.append { [weak self] in
            self?.model.settings = original
            exit(0)
        }
        func run(_ i: Int) {
            guard i < steps.count else { return }
            steps[i]()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { run(i + 1) }
        }
        run(0)
    }

    private func lazySettingsSteps(dir: URL, prefix: String) -> [() -> Void] {
        SettingsTab.allCases.flatMap { tab -> [() -> Void] in
            [
                { [weak self] in self?.settingsWindow?.show(tab) },
                { [weak self] in
                    guard let window = self?.settingsWindow?.window, let frame = window.contentView?.superview else { return }
                    SnapshotWriter.write(view: frame, appearance: window.effectiveAppearance,
                                         to: dir.appendingPathComponent("\(prefix)-settings-\(tab.rawValue).png"), material: true)
                },
            ]
        }
    }
    #endif
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
