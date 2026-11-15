import Foundation

public enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case auto, light, dark
}

/// Accent color for today and the selection. Red is deliberately absent: in a patro, red means a holiday.
public enum AccentChoice: String, Codable, CaseIterable, Sendable {
    case system, blue, teal, green, marigold, purple, graphite
}

/// Settings the widget extension also needs. The app writes them to a small JSON file that the
/// sandboxed widget can read (see the widget's entitlements).
public struct SharedSettings: Codable, Equatable, Sendable {
    /// Language of the interface: labels, buttons, messages.
    public var language: Language = .english
    /// Language of the calendar itself: BS dates, months, weekdays, tithi and festival names.
    public var calendarLanguage: Language = .nepali
    public var basis: DateBasis = .nepal
    public var appearance: AppearanceMode = .auto
    public var accent: AccentChoice = .system
    public var showTithi: Bool = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SharedSettings()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decode(T.self, forKey: key)) ?? fallback }
        language = v(.language, d.language)
        calendarLanguage = v(.calendarLanguage, d.calendarLanguage)
        basis = v(.basis, d.basis)
        appearance = v(.appearance, d.appearance)
        accent = v(.accent, d.accent)
        showTithi = v(.showTithi, d.showTithi)
    }

    /// The user's real home folder, even from inside a sandbox container.
    public static var realHome: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }

    public static var directory: URL {
        URL(fileURLWithPath: realHome).appendingPathComponent("Library/Application Support/NepaliPatro", isDirectory: true)
    }

    public static var fileURL: URL { directory.appendingPathComponent("shared-settings.json") }

    public static func load() -> SharedSettings {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(SharedSettings.self, from: data) else { return SharedSettings() }
        return s
    }

    public func save() {
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
