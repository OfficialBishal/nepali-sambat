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
        #if DEBUG
        if let dir = ProcessInfo.processInfo.environment["PATRO_SNAPSHOT_DIR"] {
            runSnapshots(to: URL(fileURLWithPath: dir))
            return
        }
        #endif
        statusBar = StatusBarController(model: model)
        model.openSettings = { [weak self] tab in self?.showSettings(tab) }
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
    /// Renders the popover's pages and the Settings tabs in several configurations to PNGs, then
    /// quits. Everything happens offscreen: no menu bar item, no visible window, and the process
    /// can't activate, so it never gets in the way of someone using the Mac.
    private func runSnapshots(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let configs: [(String, AppearanceMode, Language, Language, AccentChoice)] = [
            ("light", .light, .english, .nepali, .blue),
            ("dark", .dark, .english, .nepali, .blue),
            ("light-en", .light, .english, .english, .blue),
            ("dark-ne", .dark, .nepali, .nepali, .purple),
        ]
        var steps: [() -> Void] = []
        for (name, appearance, ui, cal, accent) in configs {
            steps.append { [weak self] in
                guard let self else { return }
                self.model.settings.appearance = appearance
                self.model.settings.language = ui
                self.model.settings.calendarLanguage = cal
                self.model.settings.accent = accent
                self.model.snapshotBackground = true
                self.model.selectedJDN = name.hasPrefix("dark") ? self.model.todayJDN + 7 : nil
            }
            for page in Page.allCases {
                steps.append { [weak self] in
                    guard let self else { return }
                    self.model.page = page
                    OffscreenRenderer.render(PanelRoot().environment(self.model), size: PanelRoot.size,
                                             appearance: appearance.nsAppearance,
                                             to: dir.appendingPathComponent("\(name)-\(page.rawValue).png"))
                }
            }
            guard name == "light" || name == "dark" else { continue }
            for tab in SettingsTab.allCases {
                steps.append { [weak self] in
                    guard let self else { return }
                    let size = tab.size(self.model)
                    OffscreenRenderer.render(tab.content.frame(width: size.width, height: size.height).environment(self.model),
                                             size: size, appearance: appearance.nsAppearance,
                                             to: dir.appendingPathComponent("\(name)-settings-\(tab.rawValue).png"))
                }
            }
        }
        steps.append { exit(0) }
        func run(_ i: Int) {
            guard i < steps.count else { return }
            steps[i]()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { run(i + 1) }
        }
        run(0)
    }
    #endif
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
// Debug renders run as a background process that can never take focus.
app.setActivationPolicy(AppModel.isRenderingProcess ? .prohibited : .accessory)
app.run()
