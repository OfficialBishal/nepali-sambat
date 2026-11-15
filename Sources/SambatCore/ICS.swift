import Foundation

/// Minimal RFC 5545 writer for all-day festival events.
public enum ICS {
    public static func calendar(from fromJDN: Int, to toJDN: Int, lang: Language, includeObservances: Bool = false,
                                name: String = "Nepali Festivals") -> String {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Sambat//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:\(escape(name))",
            "X-WR-TIMEZONE:Asia/Kathmandu",
        ]
        let stamp = utcStamp(Date())
        for e in FestivalEngine.shared.events(from: fromJDN, to: toJDN) where includeObservances || e.category != .observance {
            let start = ADDate(jdn: e.jdn), end = ADDate(jdn: e.jdn + 1)
            let bs = BSDate(jdn: e.jdn).map { Formatter.dateLong($0, .nepali) } ?? ""
            var desc = "\(e.nameNe) / \(e.nameEn)\n\(bs)"
            if e.isPublicHoliday { desc += "\nसार्वजनिक बिदा / Public holiday" }
            if let note = e.noteEn { desc += "\n\(note)" }
            lines += [
                "BEGIN:VEVENT",
                "UID:\(e.key)-\(e.jdn)@sambat",
                "DTSTAMP:\(stamp)",
                "DTSTART;VALUE=DATE:\(dateString(start))",
                "DTEND;VALUE=DATE:\(dateString(end))",
                "SUMMARY:\(escape(e.name(lang)))",
                "DESCRIPTION:\(escape(desc))",
                "CATEGORIES:\(e.isPublicHoliday ? "Public Holiday" : "Festival")",
                "TRANSP:TRANSPARENT",
                "END:VEVENT",
            ]
        }
        lines.append("END:VCALENDAR")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    static func dateString(_ d: ADDate) -> String {
        String(format: "%04d%02d%02d", d.year, d.month, d.day)
    }

    static func utcStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.string(from: date)
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Folds lines at 75 octets without splitting a UTF-8 sequence.
    static func fold(_ line: String) -> String {
        guard line.utf8.count > 75 else { return line }
        var out = ""
        var current = 0
        var limit = 75
        for ch in line {
            let n = String(ch).utf8.count
            if current + n > limit {
                out += "\r\n "
                current = 0
                limit = 74
            }
            out.append(ch)
            current += n
        }
        return out
    }
}
