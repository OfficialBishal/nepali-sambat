import AppKit
import Observation
import PatroCore
import SwiftUI

/// A borderless panel that drops down from the menu bar item.
final class DropdownPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 344, height: 600),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false
        isMovable = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class StatusBarController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = DropdownPanel()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var appearanceObservation: NSKeyValueObservation?

    init(model: AppModel) {
        self.model = model
        super.init()

        let hosting = NSHostingView(rootView: PanelRoot().environment(model))
        hosting.frame = NSRect(x: 0, y: 0, width: PanelRoot.size.width, height: PanelRoot.size.height)
        panel.contentView = hosting
        panel.setContentSize(PanelRoot.size)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityTitle("Nepali Patro")
        }
        statusItem.autosaveName = "NepaliPatroStatusItem"

        model.systemIsDark = Self.systemIsDark()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.model.systemIsDark = Self.systemIsDark() }
        }
        updateButton()
        observeModel()
    }

    private static func systemIsDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    // MARK: Menu bar label

    private func observeModel() {
        withObservationTracking {
            _ = model.menuTitle
            _ = model.settings.menuShowsIcon
            _ = model.settings.menuFormat
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateButton()
                self?.observeModel()
            }
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let title = model.menuTitle
        let s = model.settings
        if s.menuFormat == .iconOnly {
            button.image = MenuBarIcon.calendar(day: Formatter.digits(model.today.day, model.lang))
            button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        } else if s.menuShowsIcon {
            button.image = MenuBarIcon.symbol()
            button.imagePosition = .imageLeading
        } else {
            button.image = nil
        }
        let font = NSFont.menuBarFont(ofSize: 0)
        button.attributedTitle = NSAttributedString(string: title.isEmpty ? "" : (button.image == nil ? title : " " + title),
                                                    attributes: [.font: font, .baselineOffset: 0.5])
        button.toolTip = tooltip()
    }

    private func tooltip() -> String {
        let lang = model.lang
        let today = model.today
        let ad = ADDate(jdn: model.todayJDN)
        return "\(Formatter.dateLong(today, lang)), \(Formatter.weekday(JDN.weekday(model.todayJDN), lang))\n\(Formatter.adLong(ad, .english))"
    }

    // MARK: Panel

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    func togglePanel() {
        panel.isVisible ? closePanel() : openPanel()
    }

    func openPanel(page: Page? = nil) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        if let page { model.page = page }
        model.now = AppModel.currentDate()
        model.panelVisible = true

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let size = PanelRoot.size
        var x = buttonFrame.midX - size.width / 2
        x = max(visible.minX + 6, min(x, visible.maxX - size.width - 6))
        let y = buttonFrame.minY - size.height - 6
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .leftMouseDown {
                if event.window !== self.panel && event.window !== self.statusItem.button?.window && event.window?.level != .popUpMenu {
                    self.closePanel()
                }
                return event
            }
            return self.handleKey(event)
        }
    }

    func closePanel() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        model.panelVisible = false
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        // Don't steal keys from text fields (converter).
        if let responder = panel.firstResponder, responder is NSTextView { 
            if event.keyCode == 53 { closePanel(); return nil }
            return event
        }
        switch event.keyCode {
        case 53: closePanel(); return nil // esc
        case 123 where model.page == .calendar: model.step(months: -1); return nil // ←
        case 124 where model.page == .calendar: model.step(months: 1); return nil // →
        case 126 where model.page == .calendar: model.step(months: -12); return nil // ↑ year
        case 125 where model.page == .calendar: model.step(months: 12); return nil // ↓ year
        default: break
        }
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "q": NSApp.terminate(nil); return nil
            case ",": model.page = .settings; return nil
            case "w": closePanel(); return nil
            case "1": model.page = .calendar; return nil
            case "2": model.page = .converter; return nil
            case "3": model.page = .upcoming; return nil
            default: break
            }
        }
        if event.charactersIgnoringModifiers == "t", model.page == .calendar { model.goToToday(); return nil }
        return event
    }

    private func showContextMenu() {
        closePanel()
        let menu = NSMenu()
        let lang = model.lang
        let header = NSMenuItem(title: model.menuTitle.isEmpty ? Formatter.dateLong(model.today, lang) : tooltip().replacingOccurrences(of: "\n", with: " · "),
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        menu.addItem(item(model.t("Open Calendar", "पात्रो खोल्नुहोस्"), #selector(openCalendar)))
        menu.addItem(item(model.t("Date Converter", "मिति रूपान्तरण"), #selector(openConverter)))
        menu.addItem(item(model.t("Copy Today's Date", "आजको मिति कपी"), #selector(copyToday)))
        menu.addItem(item(model.t("Settings…", "सेटिङ…"), #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item(model.t("Quit Nepali Patro", "बन्द गर्नुहोस्"), #selector(quit), key: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func openCalendar() { openPanel(page: .calendar) }
    @objc private func openConverter() { openPanel(page: .converter) }
    @objc private func openSettings() { openPanel(page: .settings) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func copyToday() {
        let lang = model.lang
        Clipboard.copy("\(Formatter.dateLong(model.today, lang)), \(Formatter.weekday(JDN.weekday(model.todayJDN), lang))")
    }
}

#if DEBUG
extension StatusBarController {
    /// Renders every page in a few themes to PNG files (debug builds only).
    func writeSnapshots(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = model.settings
        let combos: [(String, Language)] = [("light", .nepali), ("dark", .english), ("himalaya", .nepali), ("midnight", .english), ("laliguras", .english), ("dhaka", .nepali), ("forest", .english)]
        var steps: [() -> Void] = []
        for (theme, lang) in combos {
            for page in Page.allCases {
                steps.append { [weak self] in
                    guard let self else { return }
                    self.model.settings.themeID = theme
                    self.model.settings.language = lang
                    if page == .calendar && theme == "dark" { self.model.select(self.model.todayJDN + 7) } else { self.model.selectedJDN = nil }
                    self.openPanel(page: page)
                }
                steps.append { [weak self] in
                    guard let self, let view = self.panel.contentView else { return }
                    if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                        view.cacheDisplay(in: view.bounds, to: rep)
                        let url = dir.appendingPathComponent("\(theme)-\(page.rawValue).png")
                        try? rep.representation(using: .png, properties: [:])?.write(to: url)
                    }
                }
            }
        }
        steps.append { [weak self] in
            self?.model.settings = original
            NSApp.terminate(nil)
        }
        func run(_ i: Int) {
            guard i < steps.count else { return }
            steps[i]()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { run(i + 1) }
        }
        run(0)
    }
}
#endif

enum MenuBarIcon {
    /// A small calendar glyph with today's day number, drawn as a template image.
    static func calendar(day: String) -> NSImage {
        let size = NSSize(width: 20, height: 17)
        let image = NSImage(size: size, flipped: false) { rect in
            let body = NSRect(x: 1.5, y: 1, width: rect.width - 3, height: rect.height - 2.5)
            let path = NSBezierPath(roundedRect: body, xRadius: 3.5, yRadius: 3.5)
            NSColor.black.setStroke()
            path.lineWidth = 1.4
            path.stroke()
            let bar = NSBezierPath(rect: NSRect(x: body.minX, y: body.maxY - 4, width: body.width, height: 4))
            NSColor.black.setFill()
            NSBezierPath(roundedRect: body, xRadius: 3.5, yRadius: 3.5).setClip()
            bar.fill()
            NSGraphicsContext.current?.cgContext.resetClip()
            let font = NSFont.systemFont(ofSize: day.count > 1 ? 9.5 : 10.5, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let s = NSAttributedString(string: day, attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: body.midX - sz.width / 2, y: body.minY + (body.height - 4 - sz.height) / 2 + 0.5))
            return true
        }
        image.isTemplate = true
        return image
    }

    static func symbol() -> NSImage? {
        let img = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Nepali Patro")
        img?.isTemplate = true
        return img
    }
}
