# Design

Nepali Sambat is a native macOS utility. The design system is mostly macOS's own. This file records the few decisions layered on top, so new screens stay consistent.

## Surfaces

| Surface | Implementation | Notes |
| --- | --- | --- |
| Calendar popover | `NSPopover` (transient) hosting SwiftUI, 340 × 596 pt | System popover material (Liquid Glass on macOS 26+, vibrancy before). Fixed height so the bottom navigation never moves under the pointer. |
| Settings | `NSTabViewController` with `.toolbar` tabs, one `Form(.grouped)` per tab | Window resizes per tab, top edge fixed. Footers are leading-aligned secondary text. |
| Bottom bar | `PillPicker` (Calendar, Convert, Festivals) filling the width, and a gear menu in a matching tile | Drawn like the macOS 26 segmented control in a form: a soft track with the chosen segment raised. The native control switches to a heavy accent fill in a popover and greys out when the popover isn't key; this looks the same in every state. The converter's AD/BS switch uses the same control. |
| Widgets | WidgetKit, `containerBackground(.background)` | Same month grid as the popover, non-interactive. |
| Menu bar | `NSStatusItem` with menu-bar font text or a template glyph | Right-click shows a standard `NSMenu`. |

No cards, no custom window chrome, no gradients, no glass panels drawn by the app.

## Color

Neutral system greys, plus three colours with one job each:

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| Accent (`Palette.accent`) | `#2864DC` | `#4D8DF7` | Today's cell, the selected date in pickers, interactive tint (pop-up buttons, toggles). Blue by default; never red, so it can't be confused with a holiday. |
| Holiday (`Palette.holiday`) | `#B8342E` | `#EF756B` | Public holidays and Saturdays, as in a printed patro, and the holiday dot. A warm brick red rather than a saturated crimson, so a month of holidays isn't loud. |
| Festival (`Palette.festival`) | `#9A6F45` | `#CDA27A` | The dot on festival days that aren't holidays. |
| Quiet text (`.quiet`) | primary at 68% | primary at 68% | AD dates, tithi, captions. System `.secondary` falls under 4.5:1 at caption sizes. |

Accent choices: Blue (default), Teal, Green, Jacaranda, Graphite, and the macOS accent color as an opt-in last choice. The macOS accent used to be the default, but on macOS 26 it can follow the wallpaper and come out yellow or red, so it is no longer the default; there is no yellow or orange accent. Each defines an `onAccent` color with at least 4.5:1 contrast (dark-mode accents use dark text). Everything else is a system semantic color (`.primary`, `.secondary`, `windowBackgroundColor`) so Increase Contrast and vibrancy behave natively.

## Type

SF Pro (system) everywhere, with Devanagari from the system fallback (Kohinoor Devanagari). There is no rounded design and no display face.

| Role | Style |
| --- | --- |
| Today's date | 22 pt semibold, year in 22 pt regular secondary |
| Page titles (Convert, Festivals) | `.title3` semibold |
| Month title, day title | `.headline` |
| Facts, event names | `.callout` (medium for names) |
| Supporting lines | `.subheadline` / `.caption`, quiet |
| Grid numeral | 15 pt regular (semibold when today), AD 8.5 pt, tithi 9 pt (8.5 pt condensed in English) |

Sentence case for every label and header. No uppercase tracked labels, no middle-dot separators (use commas or layout), no em dashes in copy.

## The patro grid (`SambatUI.MonthGrid`)

- Sunday first; weekday initials in the calendar language, Saturday in holiday red.
- Each cell: AD day in the top-right corner (the 1st carries the month: "1 Nov"), BS numeral, tithi directly below at a fixed size.
- A day is marked by its whole cell, a rounded rectangle (`DayMark`, 7 pt continuous corners, inset 1.5 pt): filled with the accent for today, with all its text in `onAccent`; a 10% primary tint for the selection; a 1 pt outline for today on the other clock. No circles. The converter's AD and BS grids use the same marks.
- Festival marker (`EventDot`) in the top-left corner, the same everywhere (grid, lists, widgets): a red dot for a public holiday, a red ring for a regional holiday, a tan dot for a festival. Holiday status is also always written out in text in the detail, lists and converter.
- Hover is a 5% primary rounded fill. Every cell has a full VoiceOver label.

## Calendar page

- Header: BS date, then weekday (calendar language) and AD date (English), then the tithi with when it ends, then today's festival if any. Nepal's clock on the right, labelled "Nepal time".
- When Nepal and the Mac are on different dates, a one-line note says so.
- Below the grid: "Coming up" (as many whole rows as fit) when nothing is selected, or the selected day's detail. Today's details aren't repeated under the grid.

## Formats

Dates are written day, month, year, the way Nepalis write them. Long BS date: weekday first ("सोमबार, ३० कात्तिक २०८३", "Monday, 30 Kartik 2083"). Short BS date: "३० कात्तिक". AD dates: always English ("16 November 2026", "16 Nov 2026", "16 Nov" with a no-break space). Month labels read month then year ("कात्तिक २०८३", "Oct – Nov 2026"). The menu bar defaults to "३० कात्तिक". Times follow the interface language; Nepali uses the spoken part of the day ("राति २:०८"). Tithi is shown as fortnight and tithi ("Shukla Saptami") without the lunar month, which reads as a mistake next to the solar month. Near today, when the two dates differ, relative labels name the place ("Today here, yesterday in Nepal").

## Motion

- Month change: a 0.2 s ease-out slide in the direction of travel, combined with a fade. Page switch: a 0.16 s crossfade.
- With Reduce Motion on, both become instant or a plain fade.
- The bottom switcher's raised segment slides between pages (0.22 s), instant with Reduce Motion.
- Nothing animates on its own except the clock's numeric transition.

## Appearance

Light, Dark or Auto applies to the whole app (`NSApp.appearance`), not only the popover. Set on the popover alone, AppKit controls hosted by SwiftUI and the popover material could resolve to the system's appearance while the rest followed the app's.

## Language

Two independent settings: the interface language (labels, buttons, sentences) and the calendar language (BS dates, weekdays, tithi, festival names). Gregorian dates are always written in English. Times follow the interface language.

## Icon

A patro page on a flag-blue squircle (superellipse, n = 5, on the 824 pt grid): a white sheet with a crimson header carrying "बैशाख", a large "१", and a second sheet peeking out beneath, like a pad you tear pages from. Crimson and blue are the colours of Nepal's flag; the coloured tile keeps it from being mistaken for Apple's Calendar. Generated by `scripts/make-icon.swift`. The menu bar glyph is a template calendar outline with today's day number.
