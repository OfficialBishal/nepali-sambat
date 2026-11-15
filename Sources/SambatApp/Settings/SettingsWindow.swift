import AppKit
import Observation
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general, menuBar, appearance, reminders, calendar, about

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .menuBar: return "menubar.arrow.up.rectangle"
        case .appearance: return "paintpalette"
        case .reminders: return "bell"
        case .calendar: return "calendar.badge.plus"
        case .about: return "info.circle"
        }
    }

    @MainActor func title(_ model: AppModel) -> String {
        switch self {
        case .general: return model.t("General", "सामान्य")
        case .menuBar: return model.t("Menu Bar", "मेनु बार")
        case .appearance: return model.t("Appearance", "रूप")
        case .reminders: return model.t("Reminders", "सूचना")
        case .calendar: return model.t("Calendar Apps", "क्यालेन्डर एप")
        case .about: return model.t("About", "बारेमा")
        }
    }

    /// Content size for a tab in its current state; the window animates between sizes like a native settings window.
    @MainActor func size(_ model: AppModel) -> CGSize {
        guard self == .reminders else { return size }
        let s = model.settings
        guard s.notificationsEnabled else { return CGSize(width: 500, height: 150) }
        return CGSize(width: 500, height: s.notifyDayBefore ? 300 : 262)
    }

    var size: CGSize {
        switch self {
        case .general: return CGSize(width: 500, height: 430)
        case .menuBar: return CGSize(width: 500, height: 215)
        case .appearance: return CGSize(width: 500, height: 290)
        case .reminders: return CGSize(width: 500, height: 300)
        case .calendar: return CGSize(width: 500, height: 330)
        case .about: return CGSize(width: 500, height: 350)
        }
    }

    @MainActor @ViewBuilder
    var content: some View {
        switch self {
        case .general: GeneralSettings()
        case .menuBar: MenuBarSettings()
        case .appearance: AppearanceSettings()
        case .reminders: ReminderSettings()
        case .calendar: CalendarSettings()
        case .about: AboutSettings()
        }
    }
}

/// Reports tab changes so the window can resize to each tab, as native settings windows do.
final class SettingsTabViewController: NSTabViewController {
    var onSelect: ((Int) -> Void)?

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        onSelect?(selectedTabViewItemIndex)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private let tabs = SettingsTabViewController()

    init(model: AppModel) {
        self.model = model
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = [.allowUserInteraction]
        for tab in SettingsTab.allCases {
            let host = NSHostingController(rootView: AccentTinted { tab.content }
                .frame(width: tab.size.width)
                .frame(maxHeight: .infinity, alignment: .top)
                .environment(model))
            host.sizingOptions = []
            host.title = tab.title(model)
            let item = NSTabViewItem(viewController: host)
            item.label = tab.title(model)
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title(model))
            item.identifier = tab.rawValue
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SambatSettings")
        super.init(window: window)
        window.delegate = self
        tabs.onSelect = { [weak self] index in
            MainActor.assumeIsolated { self?.resize(for: SettingsTab.allCases[index], animate: true) }
        }
        resize(for: .general, animate: false)
        applyAppearance()
        observe()
    }

    private func resize(for tab: SettingsTab, animate: Bool) {
        guard let window else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: tab.size(model)))
        frame.origin.x = window.frame.origin.x
        frame.origin.y = window.frame.maxY - frame.height
        window.setFrame(frame, display: true, animate: animate && window.isVisible)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ tab: SettingsTab) {
        if let index = SettingsTab.allCases.firstIndex(of: tab) { tabs.selectedTabViewItemIndex = index }
        if window?.isVisible != true { window?.center() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func observe() {
        withObservationTracking {
            _ = model.settings.language
            _ = model.settings.appearance
            _ = model.settings.notificationsEnabled
            _ = model.settings.notifyDayBefore
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.relabel()
                self.applyAppearance()
                self.resize(for: SettingsTab.allCases[self.tabs.selectedTabViewItemIndex], animate: true)
                self.observe()
            }
        }
    }

    private func applyAppearance() {
        window?.appearance = model.settings.appearance.nsAppearance
    }

    private func relabel() {
        for (item, tab) in zip(tabs.tabViewItems, SettingsTab.allCases) {
            item.label = tab.title(model)
            item.viewController?.title = tab.title(model)
        }
        window?.title = SettingsTab.allCases[tabs.selectedTabViewItemIndex].title(model)
    }
}

/// Tints Settings' controls (switches, segmented controls, links) with the app's accent colour,
/// so they match the popover.
struct AccentTinted<Content: View>: View {
    @Environment(AppModel.self) private var model
    @ViewBuilder var content: Content

    var body: some View {
        content.tint(model.palette.accent)
    }
}
