import Foundation

public enum Language: String, Codable, CaseIterable, Sendable {
    case nepali, english
}

public enum Formatter {
    public static let bsMonthsNe = ["बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज", "कात्तिक", "मंसिर", "पुस", "माघ", "फागुन", "चैत"]
    public static let bsMonthsEn = ["Baisakh", "Jestha", "Asar", "Shrawan", "Bhadra", "Asoj", "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra"]

    public static let weekdaysNe = ["आइतबार", "सोमबार", "मंगलबार", "बुधबार", "बिहीबार", "शुक्रबार", "शनिबार"]
    public static let weekdaysEn = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    public static let weekdaysShortNe = ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"]
    public static let weekdaysShortEn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public static let adMonthsEn = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    public static let adMonthsShortEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    public static let adMonthsNe = ["जनवरी", "फेब्रुअरी", "मार्च", "अप्रिल", "मे", "जुन", "जुलाई", "अगस्ट", "सेप्टेम्बर", "अक्टोबर", "नोभेम्बर", "डिसेम्बर"]

    /// Lunar month names, index 0 = Chaitra.
    public static let lunarMonthsNe = ["चैत्र", "वैशाख", "ज्येष्ठ", "आषाढ", "श्रावण", "भाद्र", "आश्विन", "कार्तिक", "मार्ग", "पौष", "माघ", "फाल्गुन"]
    public static let lunarMonthsEn = ["Chaitra", "Baisakh", "Jestha", "Asar", "Shrawan", "Bhadra", "Ashwin", "Kartik", "Mangsir", "Poush", "Magh", "Falgun"]

    public static let tithisNe = ["प्रतिपदा", "द्वितीया", "तृतीया", "चतुर्थी", "पञ्चमी", "षष्ठी", "सप्तमी", "अष्टमी", "नवमी", "दशमी", "एकादशी", "द्वादशी", "त्रयोदशी", "चतुर्दशी"]
    public static let tithisEn = ["Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami", "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi"]

    private static let devanagariDigits: [Character] = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

    public static func digits(_ value: Int, _ lang: Language) -> String {
        digits(String(value), lang)
    }

    public static func digits(_ text: String, _ lang: Language) -> String {
        guard lang == .nepali else { return text }
        return String(text.map { c in
            if let v = c.wholeNumberValue, c.isASCII { return devanagariDigits[v] }
            return c
        })
    }

    public static func padded(_ value: Int, _ lang: Language) -> String {
        digits(String(format: "%02d", value), lang)
    }

    public static func bsMonth(_ month: Int, _ lang: Language) -> String {
        guard (1...12).contains(month) else { return "" }
        return lang == .nepali ? bsMonthsNe[month - 1] : bsMonthsEn[month - 1]
    }

    public static func adMonth(_ month: Int, _ lang: Language, short: Bool = false) -> String {
        guard (1...12).contains(month) else { return "" }
        if lang == .nepali { return adMonthsNe[month - 1] }
        return short ? adMonthsShortEn[month - 1] : adMonthsEn[month - 1]
    }

    public static func weekday(_ weekday: Int, _ lang: Language, short: Bool = false) -> String {
        let i = ((weekday % 7) + 7) % 7
        switch (lang, short) {
        case (.nepali, false): return weekdaysNe[i]
        case (.nepali, true): return weekdaysShortNe[i]
        case (.english, false): return weekdaysEn[i]
        case (.english, true): return weekdaysShortEn[i]
        }
    }

    /// "कात्तिक २९, २०८३" / "Kartik 29, 2083"
    public static func dateLong(_ bs: BSDate, _ lang: Language) -> String {
        "\(bsMonth(bs.month, lang)) \(digits(bs.day, lang)), \(digits(bs.year, lang))"
    }

    /// "२०८३/०७/२९"
    public static func dateNumeric(_ bs: BSDate, _ lang: Language, separator: String = "/") -> String {
        "\(digits(bs.year, lang))\(separator)\(padded(bs.month, lang))\(separator)\(padded(bs.day, lang))"
    }

    /// "November 15, 2026"
    public static func adLong(_ ad: ADDate, _ lang: Language) -> String {
        "\(adMonth(ad.month, lang)) \(digits(ad.day, lang)), \(digits(ad.year, lang))"
    }

    public static func adShort(_ ad: ADDate, _ lang: Language) -> String {
        "\(adMonth(ad.month, lang, short: true)) \(digits(ad.day, lang))"
    }

    public static func tithiOnly(_ tithi: Int, _ lang: Language) -> String {
        if tithi == 15 { return lang == .nepali ? "पूर्णिमा" : "Purnima" }
        if tithi == 30 { return lang == .nepali ? "औंसी" : "Aunsi" }
        let i = (tithi - 1) % 15
        return lang == .nepali ? tithisNe[i] : tithisEn[i]
    }

    public static func paksha(_ p: Paksha, _ lang: Language) -> String {
        switch (p, lang) {
        case (.shukla, .nepali): return "शुक्ल"
        case (.krishna, .nepali): return "कृष्ण"
        case (.shukla, .english): return "Shukla"
        case (.krishna, .english): return "Krishna"
        }
    }

    public static func lunarMonth(_ index: Int, _ lang: Language) -> String {
        let i = ((index % 12) + 12) % 12
        return lang == .nepali ? lunarMonthsNe[i] : lunarMonthsEn[i]
    }

    /// "मार्ग कृष्ण एकादशी" — purnimanta naming as printed in Nepali patros.
    public static func tithiName(_ day: DayPanchang, _ lang: Language) -> String {
        var month = lunarMonth(day.purnimantaMonth, lang)
        if day.isAdhikMonth {
            month = (lang == .nepali ? "अधिक " : "Adhik ") + month
        }
        return "\(month) \(paksha(day.paksha, lang)) \(tithiOnly(day.tithi, lang))"
    }

    public static func time(_ date: Date, in tz: TimeZone, _ lang: Language, seconds: Bool = false) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = seconds ? "h:mm:ss a" : "h:mm a"
        return digits(f.string(from: date), lang)
    }

    public static func relativeDays(_ days: Int, _ lang: Language) -> String {
        switch (days, lang) {
        case (0, .nepali): return "आज"
        case (0, .english): return "Today"
        case (1, .nepali): return "भोलि"
        case (1, .english): return "Tomorrow"
        case (-1, .nepali): return "हिजो"
        case (-1, .english): return "Yesterday"
        case (_, .nepali): return days > 0 ? "\(digits(days, lang)) दिन पछि" : "\(digits(-days, lang)) दिन अघि"
        case (_, .english): return days > 0 ? "in \(days) days" : "\(-days) days ago"
        }
    }
}
