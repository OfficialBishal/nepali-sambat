# Product

## Register

product

## Users

Nepalis living outside Nepal (the US, Europe, Australia, the Gulf) who use a Mac every day and want the Nepali date at a glance. They are fluent in English and use macOS in English, but they read the patro in Nepali: बैशाख, तिथि, चाडपर्व. Typical moments: checking whether today is a holiday back home before calling family, finding out when Dashain or Tihar falls this year, converting a birthday between BS and AD, and noticing that Nepal has already moved on to tomorrow.

## Product Purpose

A menu bar Nepali calendar that is right for people who aren't in Nepal. "Today" follows Nepal time by default, so the date changes at midnight in Kathmandu, and the app says so when Nepal and the Mac disagree. Success means it disappears into macOS: glance, get the date and the tithi, close it. It is accurate enough that nobody has to double-check it against Hamro Patro.

## Brand Personality

Quiet, precise, rooted. It should feel like something Apple might have shipped if it made a Nepali calendar: native controls, system materials, restrained color. The Nepali identity comes from the content itself (Devanagari numerals, red holidays as in a printed patro, crimson and blue from the flag used only where they mean something), not from decoration.

## Anti-references

- Generic AI-built utility UI: gradient-washed backgrounds, cards inside cards, uppercase eyebrow labels, colored side-stripes, emoji used as icons, middle-dot metadata strings, pill badges on everything.
- Ad-heavy Nepali calendar apps with dense tiles, banners, horoscope widgets and a different color on every element.
- Custom-drawn controls where macOS already has one (tabs, segmented controls, settings forms).

## Design Principles

1. **Native first.** Use the system popover, materials, SF type, SF Symbols and standard controls. Only draw something custom when macOS has no equivalent (the patro grid).
2. **Color carries meaning.** Red means a holiday (the patro convention), the accent means today or the selection. Nothing else gets color.
3. **The patro, not a dashboard.** Show the Nepali date, the tithi and festivals the way a printed patro does, with less clutter. Every element earns its place.
4. **Honest about time.** Always make clear whose day it is: Nepal's or the Mac's.
5. **Two languages, cleanly separated.** The interface language and the calendar language are independent.

## Accessibility & Inclusion

WCAG AA contrast for text, including the small AD dates and tithi in the grid. Every day cell has a full VoiceOver label (BS date, weekday, AD date, festivals). Fully usable from the keyboard (arrows, T, Esc, ⌘,). Respects Reduce Motion and Increase Contrast. Holidays are never signalled by color alone: the detail view names them.
