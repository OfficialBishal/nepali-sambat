import Foundation

/// Settings the widget extension also needs. The app writes them to a small JSON file that the
/// sandboxed widget can read (see the widget's entitlements).
public struct SharedSettings: Codable, Equatable, Sendable {
    public var language: Language = .nepali
    public var basis: DateBasis = .nepal
    public var themeID: String = "system"
    public var showTithi: Bool = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = (try? c.decode(Language.self, forKey: .language)) ?? .nepali
        basis = (try? c.decode(DateBasis.self, forKey: .basis)) ?? .nepal
        themeID = (try? c.decode(String.self, forKey: .themeID)) ?? "system"
        showTithi = (try? c.decode(Bool.self, forKey: .showTithi)) ?? true
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
