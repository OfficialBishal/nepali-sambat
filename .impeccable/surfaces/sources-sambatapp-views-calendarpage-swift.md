---
version: 1
slug: "sources-sambatapp-views-calendarpage-swift"
primary_target: "Sources/SambatApp/Views/CalendarPage.swift"
related_targets: ["Sources/SambatWidgets/Widgets.swift"]
---

# Surface brief: Sambat menu bar popover

Scope: the menu bar popover (Calendar, Convert, Festivals), with widgets and the app icon following it. Visitor mode: Operate.
Audience: Nepalis abroad on a Mac who glance at Nepal's date, tithi and holidays, convert dates, and plan around festivals.
Constraints: native macOS controls and navigation stay standard (segmented control, ControlGroup, menus, Settings window). Must not resemble Nepali Patro, Hamro Patro, kshitij's Nepali Calendar, or Apple Calendar.

## Direction contract

THESIS: Nepal's day is woven, not boxed. The popover reads like a length of Palpali dhaka: refusing both the red-and-black wall-patro grid every Nepali app copies and the grey Apple-Calendar clone.

OWN-WORLD: Loom-black header field (warm indigo-black) on every page; system body below. Dhaka thread colours with jobs: madder red = holiday, saffron = today/selection, jamara green = festival, cotton white = header type. Every marker is a lozenge, never a circle or box. SF Pro with Kohinoor Devanagari, tight dense rhythm.

STORY: Glance and know Nepal's date, where the moon is in its fortnight, whether today is a holiday; convert a date; see what festival is next.

FIRST VIEWPORT: Loom header: BS date large left, Nepal time right, weekday and AD date beneath, then the woven tithi band: 30 lozenges in two fortnights, past tithis filled, today's saffron, caption naming the tithi and when it ends. Body: month bar with native controls, lozenge-marked grid, day detail. Bottom: native segmented control and gear menu.

FORM: Palpali dhaka weave, position 5 of 7, seed:765ad6d0b8ebbbf0

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
