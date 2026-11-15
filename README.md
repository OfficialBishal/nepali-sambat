<p align="center">
  <img src="docs/icon.png" width="128" alt="Nepali Sambat icon">
</p>

<h1 align="center">Nepali Sambat</h1>

<p align="center">
  A Nepali (Bikram Sambat) calendar for the macOS menu bar that follows <b>Nepal time</b>.<br>
  Festivals, tithi, a date converter, and desktop widgets. Works offline, with no tracking.
</p>

<p align="center">
  <code>brew install --cask officialbishal/tap/nepali-sambat</code>
</p>

<p align="center">
  <img src="docs/calendar-light.png" width="300" alt="The calendar just after midnight in Nepal, while it is still Sunday in New York">
  &nbsp;
  <img src="docs/calendar-dark-nepali.png" width="300" alt="The calendar in dark mode with a Nepali interface">
</p>

---

## Why another Nepali calendar?

Most Nepali calendar apps work out "today" from your Mac's clock. If you live outside Nepal, say in the US, the Nepali date in your menu bar stays on yesterday for half a day. Nepal moves to the next day at midnight Nepal time, which is 1:15 PM in New York and 10:15 AM in California, but the app waits for your own midnight.

**Nepali Sambat uses Nepal Standard Time (UTC+05:45) by default.** The menu bar, calendar, and widgets change at midnight in Nepal, wherever you are. When Nepal and your Mac are on different dates, the app tells you: *"It's Monday in Nepal and still Sunday, Nov 15 here."* If you'd rather follow your local clock, you can switch with one setting.

## Features

- **Menu bar date**: `२९ कात्तिक`, `२९ कात्तिक, आइत`, `२०८३/०७/२९`, a calendar icon, and more, with the time in Nepal if you want it.
- **The month, the way a patro prints it**: Nepali dates with the English date in the corner, the tithi for each day, today's cell in your accent colour, holidays and Saturdays in red, and a dot on festival days (red for a public holiday, tan for other festivals). When Nepal and your Mac are on different dates, your local date is outlined. Dates are written the Nepali way: day, month, year.
- **Tithi and panchang**: the tithi with its end time, sunrise and sunset in Kathmandu, and the Nepal Sambat year.
- **Festivals and holidays**: Dashain, Tihar, Chhath, Teej, Lhosars, Eid, and more. These are worked out from astronomy and the rules Nepali patros use, then checked against the Government of Nepal's holiday lists for 2082 and 2083 BS (see [accuracy](#accuracy)).
- **Date converter** (AD to BS and BS to AD) in both directions, 1975–2100 BS (1918–2044 AD).
- **Festivals** grouped by month, with a "public holidays only" filter.
- **Festival reminders**: on the day at a time you choose, and the evening before if you like.
- **Apple Calendar**: your own events appear under the selected day, and one click writes Nepali festivals into a "Nepali Festivals" calendar. You can also export a `.ics` file or copy a feed URL for Google Calendar or Outlook.
- **Desktop widgets**: today's date (small and medium) and the full month (large). They also follow Nepal time.
- **Two separate languages**: an English interface with Nepali dates, a fully Nepali interface, or English throughout. The interface language and the calendar language are independent settings.
- **Native look**: a system popover, a standard Settings window, Light, Dark or Auto, and six accent colors (blue by default). Red is never an accent, because in a patro red means a holiday.
- **Keyboard shortcuts**: ← → change month, ↑ ↓ change year, `T` goes to today, `⌘1`–`⌘3` switch pages, `⌘,` opens Settings, Esc closes.
- **`sambat` command-line tool**, installed with the app:

```console
$ sambat
सोमबार, ३० कात्तिक २०८३
Monday, 16 November 2026
कार्तिक शुक्ल सप्तमी

$ sambat upcoming 3 --en
21 Mangsir   7 Dec    Bala Chaturdashi  (In 21 days)
28 Mangsir   14 Dec   Vivah Panchami  (In 28 days)
9 Poush      24 Dec   Udhauli / Yomari Punhi ★  (In 38 days)

$ sambat bs2ad 2083-07-22 --en      # also: ad2bs, month, events, ics
```

<p align="center">
  <img src="docs/converter.png" width="250" alt="Date converter">
  <img src="docs/festivals.png" width="250" alt="Upcoming festivals">
</p>
<p align="center">
  <img src="docs/settings.png" width="420" alt="Settings window">
</p>
<p align="center">
  <img src="docs/widget-medium.png" width="364" alt="Medium widget">
  <img src="docs/widget-large.png" width="250" alt="Large widget">
</p>

It has no network access, no analytics, and no account. The app is a few MB and runs entirely offline. The only network request is an optional daily update check against GitHub Releases.

## Install

### Homebrew (recommended)

```sh
brew install --cask officialbishal/tap/nepali-sambat
```

Upgrade with `brew upgrade --cask nepali-sambat`.

The app is ad-hoc signed rather than notarized by Apple, so the cask clears the download quarantine flag for you. You don't need `sudo xattr`.

### Manual

Download the latest `NepaliSambat-x.y.z.dmg` from [Releases](https://github.com/OfficialBishal/nepali-sambat/releases/latest) and drag **Nepali Sambat** to Applications. Then run this once:

```sh
xattr -dr com.apple.quarantine "/Applications/Nepali Sambat.app"
```

Requires macOS 14 Sonoma or later, on Apple silicon or Intel.

### Widgets

Open the app once, then right-click the desktop, choose **Edit Widgets…**, and search for "Nepali" or "Sambat".

## Subscribe from any calendar app

The festival calendar is also published as an iCalendar feed that works with Google Calendar, Outlook, and others:

- English: `https://raw.githubusercontent.com/OfficialBishal/nepali-sambat/main/calendar/nepali-festivals.ics`
- नेपाली: `https://raw.githubusercontent.com/OfficialBishal/nepali-sambat/main/calendar/nepali-festivals-ne.ics`

## Accuracy

- **BS ↔ AD conversion** uses the standard month-length table for 1975–2100 BS. It is cross-checked against two independent open datasets and against computed solar ingresses (sankranti).
- **Tithi** is the one in force at sunrise in Kathmandu, as printed in Nepali patros. It is computed with the Moon and Sun theories from Meeus' *Astronomical Algorithms*, and full and new moon times come out within about a minute.
- **Lunar festivals** follow the patro rules. The tithi is usually taken at sunrise (udaya), with the traditional exceptions: Maha Navami at midday, Vijaya Dashami and Ghode Jatra in the afternoon, Laxmi Puja and Chhath at sunset, and Shivaratri at midnight. Adhik (leap) months are skipped. Every festival in the 2082 and 2083 BS government holiday lists comes out on the right day (see `swift run SambatChecks`).
- **Things that can differ**: Eid follows moon sighting and may move by a day. Tibetan-calendar Lhosars are approximated by their lunar month. The government can also declare extra holidays. If you spot a wrong date, please [open an issue](https://github.com/OfficialBishal/nepali-sambat/issues).

## Build from source

You only need the Xcode Command Line Tools.

```sh
git clone https://github.com/OfficialBishal/nepali-sambat && cd nepali-sambat
swift run SambatChecks          # run the self-checks
./scripts/build.sh             # → dist/Nepali Sambat.app and dist/NepaliSambat-<version>.dmg
```

| Target | What it is |
| --- | --- |
| `SambatCore` | Calendar data, BS↔AD conversion, Nepal-time "today", astronomy, tithi, festival engine, ICS |
| `SambatUI` | Shared SwiftUI pieces (palette, festival dot, month grid) |
| `SambatApp` | The menu bar app |
| `SambatWidgets` | The WidgetKit extension |
| `SambatCLI` | The command-line tool (`sambat`) |
| `SambatChecks` | Self-checks: conversions, the Nepal-midnight flip, and official holiday dates |

Design decisions are documented in [DESIGN.md](DESIGN.md) and the product brief in [PRODUCT.md](PRODUCT.md).

## License

MIT © Bishal Shrestha
