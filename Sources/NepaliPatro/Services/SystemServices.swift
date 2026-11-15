import AppKit
import Observation
import PatroCore
import ServiceManagement
import UniformTypeIdentifiers

enum AppInfo {
    static let repo = "OfficialBishal/nepali-patro"
    static let caskName = "officialbishal/tap/nepali-patro"
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }
    static var repoURL: URL { URL(string: "https://github.com/\(repo)")! }
    static var releasesURL: URL { URL(string: "https://github.com/\(repo)/releases/latest")! }
    static var issuesURL: URL { URL(string: "https://github.com/\(repo)/issues")! }
}

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            NSLog("Launch at login failed: \(error)")
            return false
        }
    }
}

@MainActor
@Observable
final class UpdateChecker {
    private(set) var latestVersion: String?
    private(set) var checking = false
    private(set) var lastError: String?

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return Self.compare(latest, AppInfo.version) == .orderedDescending
    }

    private let lastCheckKey = "lastUpdateCheck"

    func checkIfDue() {
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        if Date().timeIntervalSince1970 - last > 86_400 { Task { await check() } }
    }

    func check() async {
        checking = true
        defer { checking = false }
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(AppInfo.repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Release: Decodable { let tag_name: String }
            let release = try JSONDecoder().decode(Release.self, from: data)
            latestVersion = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            lastError = nil
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
        } catch {
            lastError = error.localizedDescription
        }
    }

    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}

enum ICSExport {
    @MainActor
    static func run(lang: Language) {
        guard let year = NepalTime.today()?.year, let from = BSCalendar.startJDN(year: year) else { return }
        let to = BSCalendar.startJDN(year: year + 2) ?? from + 730
        let text = ICS.calendar(from: from, to: to, lang: lang)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "ics") ?? .data]
        panel.nameFieldStringValue = "Nepali Festivals \(year)-\(year + 1).ics"
        panel.level = .popUpMenu
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? text.data(using: .utf8)?.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

enum Clipboard {
    static func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}
