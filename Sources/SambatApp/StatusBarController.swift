import AppKit
import Observation
import SambatCore
import SambatUI
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var keyMonitor: Any?

    init(model: AppModel) {
        self.model = model
        super.init()

        let hosting = NSHostingController(rootView: PanelRoot().environment(model))
        hosting.sizingOptions = []
        popover.contentViewController = hosting
        popover.contentSize = PanelRoot.size
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityTitle("Nepali Sambat")
        }
        statusItem.autosaveName = "SambatStatusItem"

        model.closePopover = { [weak self] in self?.closePopover() }
        updateButton()
        updateAppearance()
        observeModel()
    }

    // MARK: Menu bar label

    private func observeModel() {
        withObservationTracking {
            _ = model.menuTitle
            _ = model.settings.menuShowsIcon
            _ = model.settings.menuFormat
            _ = model.settings.appearance
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateButton()
                self?.updateAppearance()
                self?.observeModel()
            }
        }
    }

    private func updateAppearance() {
        // Set app-wide, not only on the popover: otherwise AppKit controls hosted by SwiftUI (pop-up
        // buttons) and the popover material can resolve to the system's appearance while the rest of
        // the content uses the app's, leaving light controls on a dark popover or the reverse.
        let appearance = model.settings.appearance.nsAppearance
        NSApp.appearance = appearance
        popover.appearance = appearance
        popover.contentViewController?.view.window?.appearance = appearance
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let title = model.menuTitle
        let s = model.settings
        if s.menuFormat == .iconOnly {
            button.image = MenuBarIcon.calendar(day: Formatter.digits(model.today.day, model.cal))
            button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        } else if s.menuShowsIcon {
            button.image = MenuBarIcon.symbol()
            button.imagePosition = .imageLeading
        } else {
            button.image = nil
        }
        let font = NSFont.menuBarFont(ofSize: 0)
        let text = title.isEmpty ? "" : (button.image == nil ? title : " " + title)
        button.attributedTitle = NSAttributedString(string: text, attributes: [.font: font, .baselineOffset: 0.5])
        button.toolTip = tooltip()
    }

    private func tooltip() -> String {
        let jdn = model.todayJDN
        return "\(Formatter.dateFull(model.today, weekday: JDN.weekday(jdn), model.cal))\n\(Formatter.adLong(ADDate(jdn: jdn), .english))"
    }

    // MARK: Popover

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        popover.isShown ? closePopover() : openPopover()
    }

    func openPopover(page: Page? = nil) {
        guard let button = statusItem.button else { return }
        if let page { model.page = page }
        model.now = AppModel.currentDate()
        model.panelVisible = true
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }
    }

    func closePopover() {
        if popover.isShown { popover.performClose(nil) }
    }

    func popoverDidClose(_ notification: Notification) {
        model.panelVisible = false
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
        // Hand focus back to the previous app unless one of our windows (Settings) is open.
        let ownWindowOpen = NSApp.windows.contains { $0.isVisible && $0.level == .normal && $0.styleMask.contains(.titled) }
        if !ownWindowOpen { NSApp.hide(nil) }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard popover.isShown else { return event }
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "q": NSApp.terminate(nil); return nil
            case ",": closePopover(); model.openSettings(.general); return nil
            case "w": closePopover(); return nil
            case "1": model.page = .calendar; return nil
            case "2": model.page = .converter; return nil
            case "3": model.page = .upcoming; return nil
            default: return event
            }
        }
        // Leave keys alone while a text field (the converter's date field) is being edited.
        if popover.contentViewController?.view.window?.firstResponder is NSText { return event }
        guard model.page == .calendar else { return event }
        switch event.keyCode {
        case 123: model.step(months: -1); return nil
        case 124: model.step(months: 1); return nil
        case 126: model.step(months: -12); return nil
        case 125: model.step(months: 12); return nil
        default: break
        }
        if event.charactersIgnoringModifiers == "t" { model.goToToday(); return nil }
        return event
    }

    private func showContextMenu() {
        closePopover()
        let menu = NSMenu()
        let header = NSMenuItem(title: tooltip().replacingOccurrences(of: "\n", with: "   "), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        menu.addItem(item(model.t("Open Calendar", "पात्रो खोल्नुहोस्"), #selector(openCalendar)))
        menu.addItem(item(model.t("Convert a Date", "मिति रूपान्तरण"), #selector(openConverter)))
        menu.addItem(item(model.t("Copy Today’s Date", "आजको मिति कपी गर्नुहोस्"), #selector(copyToday)))
        menu.addItem(.separator())
        menu.addItem(item(model.t("Settings…", "सेटिङ…"), #selector(openSettings), key: ","))
        menu.addItem(item(model.t("Quit Nepali Sambat", "Nepali Sambat बन्द गर्नुहोस्"), #selector(quit), key: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func openCalendar() { openPopover(page: .calendar) }
    @objc private func openConverter() { openPopover(page: .converter) }
    @objc private func openSettings() { model.openSettings(.general) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func copyToday() {
        Clipboard.copy(Formatter.dateFull(model.today, weekday: JDN.weekday(model.todayJDN), model.cal))
    }
}

#if DEBUG
/// Debug builds only: draws a SwiftUI view to PNG in a window that is never put on screen.
@MainActor
enum OffscreenRenderer {
    private static var windows: [NSWindow] = []

    static func render<V: View>(_ view: V, size: CGSize, appearance: NSAppearance?, to url: URL) {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = appearance
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        windows.append(window)
        // Give SwiftUI a run loop turn to build the view, then draw it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            host.layoutSubtreeIfNeeded()
            SnapshotWriter.write(view: host, appearance: window.effectiveAppearance, to: url, material: true)
            windows.removeAll { $0 === window }
        }
    }
}

enum SnapshotWriter {
    /// Draws a view hierarchy to PNG. Behind-window materials can't be captured offscreen, so the
    /// popover material is approximated with a flat colour for the appearance.
    @MainActor
    static func write(view: NSView, appearance: NSAppearance, to url: URL, material: Bool) {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        appearance.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: rep)
        }
        let size = view.bounds.size
        let image = NSImage(size: size)
        image.lockFocus()
        if material {
            NSColor(srgbRed: isDark ? 0.17 : 0.95, green: isDark ? 0.17 : 0.95, blue: isDark ? 0.18 : 0.95, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 12, yRadius: 12).fill()
        }
        rep.draw(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
    }
}
#endif

enum MenuBarIcon {
    /// A small calendar glyph with today's day number, drawn as a template image.
    static func calendar(day: String) -> NSImage {
        let size = NSSize(width: 19, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            let body = NSRect(x: 1, y: 0.75, width: rect.width - 2, height: rect.height - 1.5)
            let outline = NSBezierPath(roundedRect: body, xRadius: 3.5, yRadius: 3.5)
            NSColor.black.setStroke()
            outline.lineWidth = 1.25
            outline.stroke()
            NSBezierPath(rect: NSRect(x: body.minX + 0.6, y: body.maxY - 3.6, width: body.width - 1.2, height: 0.9)).fill()
            let font = NSFont.systemFont(ofSize: day.count > 1 ? 9 : 9.5, weight: .semibold)
            let s = NSAttributedString(string: day, attributes: [.font: font, .foregroundColor: NSColor.black])
            let sz = s.size()
            s.draw(at: NSPoint(x: body.midX - sz.width / 2, y: body.minY + (body.height - 3.6 - sz.height) / 2 + 0.3))
            return true
        }
        image.isTemplate = true
        return image
    }

    static func symbol() -> NSImage? {
        let img = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Nepali Sambat")
        img?.isTemplate = true
        return img
    }
}
