import AppKit
import Combine
import IslandCore
import SwiftUI

@main
struct IslandApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = ShellSettings()
    private let interaction = IslandInteraction()
    private let registry = ModuleRegistry()
    private let loginItem = LoginItemController()
    private let nowPlayingPreferences = NowPlayingPreferences()
    private lazy var nowPlaying: NowPlayingModule = {
        let bundle = Bundle.main.bundleURL
        let primary = MediaRemoteSource(scriptURL: bundle.appendingPathComponent("Contents/Resources/NowPlaying/mediaremote-adapter.pl"),
                                        frameworkURL: bundle.appendingPathComponent("Contents/Frameworks/MediaRemoteAdapter.framework"))
        let backup = AppleEventsSource(preferences: nowPlayingPreferences)
        return NowPlayingModule(coordinator: NowPlayingCoordinator(primary: primary, backup: backup, preferences: nowPlayingPreferences))
    }()
    private lazy var panel = IslandPanelController(settings: settings, interaction: interaction)
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var subscriptions: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.setContent(ShellView(panel: panel, interaction: interaction, registry: registry,
                                  openSettings: { [weak self] in self?.showSettings() }))
        panel.start()
        installMenuBarItem()
        settings.$isVisible.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateMenu() }
        }.store(in: &subscriptions)
        registry.register(nowPlaying, enabled: nowPlayingPreferences.isEnabled)
        nowPlayingPreferences.$isEnabled.sink { [weak self] enabled in
            Task { @MainActor [weak self] in self?.registry.setEnabled(enabled, for: "now-playing") }
        }.store(in: &subscriptions)
        interaction.$isCompactPreviewEnabled.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateMenu() }
        }.store(in: &subscriptions)
        registry.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.interaction.setHasActiveModule(self.registry.activeModule != nil)
            }
        }.store(in: &subscriptions)
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel.stop()
        registry.stopAll()
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Island")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "Island"
        let menu = NSMenu()
        let visibility = menu.addItem(withTitle: "Show Island", action: #selector(toggleVisibility), keyEquivalent: "")
        visibility.target = self
        visibility.tag = 1
        let preview = menu.addItem(withTitle: "Preview Compact Layout", action: #selector(toggleCompactPreview), keyEquivalent: "")
        preview.target = self
        preview.tag = 2
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Island", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        updateMenu()
    }

    private func updateMenu() {
        statusItem?.menu?.item(withTag: 1)?.state = settings.isVisible ? .on : .off
        statusItem?.menu?.item(withTag: 2)?.state = interaction.isCompactPreviewEnabled ? .on : .off
    }

    @objc private func toggleVisibility() { settings.isVisible.toggle() }
    @objc private func toggleCompactPreview() { interaction.setCompactPreview(!interaction.isCompactPreviewEnabled) }

    @objc private func showSettings() {
        interaction.dismiss()
        loginItem.refresh()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Island Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings, panel: panel, loginItem: loginItem,
                                                                      playbackPreferences: nowPlayingPreferences,
                                                                      playback: nowPlaying.coordinator))
            window.center()
            settingsWindow = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
