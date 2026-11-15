import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusBar: StatusBarController!
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App Nap can hold a menu bar app's timers for minutes; the date must flip right at Nepal midnight.
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep],
                                                         reason: "Keep the Nepali date in the menu bar on time")
        model = AppModel()
        statusBar = StatusBarController(model: model)
        #if DEBUG
        if let dir = ProcessInfo.processInfo.environment["PATRO_SNAPSHOT_DIR"] {
            statusBar.writeSnapshots(to: URL(fileURLWithPath: dir))
            return
        }
        #endif
        if !UserDefaults.standard.bool(forKey: "didShowWelcome") {
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.statusBar.openPanel(page: .calendar)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar.openPanel()
        return false
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
