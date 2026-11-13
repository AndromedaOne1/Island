import AppKit
import Combine
import SwiftUI

@MainActor
public final class IslandPanelController: NSObject, ObservableObject {
    @Published public private(set) var layout: IslandLayout?
    @Published public private(set) var screens: [ScreenGeometry] = []
    public let panel = IslandPanel()
    private let settings: ShellSettings
    private let interaction: IslandInteraction
    private var metrics = SurfaceMetrics.zero
    private var subscriptions: Set<AnyCancellable> = []
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var pointerTimer: Timer?

    public init(settings: ShellSettings, interaction: IslandInteraction) {
        self.settings = settings
        self.interaction = interaction
        super.init()
    }

    public func setContent<Content: View>(_ content: Content) {
        let hostingView = IslandHostingView(rootView: content)
        hostingView.safeAreaRegions = []
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        hostingView.pointerChanged = { [weak self] in self?.updatePointer() }
        panel.contentView = hostingView
    }

    public func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged(_:)),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(screenChanged(_:)),
                              name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(screenChanged(_:)),
                              name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        settings.$isVisible.removeDuplicates().sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshScreen() }
        }.store(in: &subscriptions)
        settings.$selectedDisplayID.removeDuplicates().sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshScreen() }
        }.store(in: &subscriptions)
        settings.$hoverDelay.sink { [weak self] delay in self?.interaction.hoverDelay = delay }
            .store(in: &subscriptions)

        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                         .otherMouseDragged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        refreshScreen()
    }

    public func stop() {
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        pointerTimer?.invalidate()
        pointerTimer = nil
        interaction.reset()
        panel.orderOut(nil)
    }

    // SwiftUI reports its interpolated geometry, keeping transparent corners and
    // the unused canvas clickable through even while a spring is in flight.
    public func updateSurfaceMetrics(_ metrics: SurfaceMetrics) {
        self.metrics = metrics
        updatePointer()
    }

    @objc private func screenChanged(_ notification: Notification) { refreshScreen() }

    public func refreshScreen() {
        screens = NSScreen.screens.map(ScreenGeometry.init(screen:))
        let mainID = NSScreen.main.map { ScreenGeometry(screen: $0).id }
        interaction.reset()
        guard settings.isVisible,
              let selected = ScreenGeometry.select(from: screens, preferredID: settings.selectedDisplayID, mainID: mainID)
        else {
            pointerTimer?.invalidate()
            pointerTimer = nil
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
            layout = nil
            return
        }
        let next = IslandLayout(screen: selected)
        layout = next
        metrics = next.metrics(for: interaction.presentation)
        panel.setFrame(next.panelFrame, display: true)
        panel.orderFrontRegardless()
        if pointerTimer == nil {
            // A low-frequency position check also works when the menu run loop
            // consumes mouse moves, or the transparent panel ignores events.
            let timer = Timer(timeInterval: 1.0 / 30.0, target: self,
                              selector: #selector(pointerTick(_:)), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            pointerTimer = timer
        }
        updatePointer()
    }

    @objc private func pointerTick(_ timer: Timer) { updatePointer() }

    private func updatePointer() {
        guard settings.isVisible, panel.isVisible, let layout else { return }
        let inside = layout.contains(NSEvent.mouseLocation, metrics: metrics)
        panel.ignoresMouseEvents = !inside
        if inside { interaction.pointerEntered() } else { interaction.pointerExited() }
    }

    private func handle(_ event: NSEvent) {
        guard settings.isVisible, panel.isVisible, let layout else { return }
        updatePointer()
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(event.type),
           !layout.contains(NSEvent.mouseLocation, metrics: metrics) {
            interaction.dismiss()
        }
    }
}
