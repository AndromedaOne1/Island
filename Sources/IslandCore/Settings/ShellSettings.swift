import Combine
import Foundation

@MainActor
public final class ShellSettings: ObservableObject {
    private let defaults: UserDefaults
    @Published public var isVisible: Bool {
        didSet { defaults.set(isVisible, forKey: "island.overlayVisible") }
    }
    @Published public var selectedDisplayID: String {
        didSet { defaults.set(selectedDisplayID, forKey: "island.selectedDisplayID") }
    }
    @Published public var hoverDelay: Double {
        didSet { defaults.set(hoverDelay, forKey: "island.hoverDelay") }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isVisible = defaults.object(forKey: "island.overlayVisible") as? Bool ?? true
        selectedDisplayID = defaults.string(forKey: "island.selectedDisplayID") ?? ""
        let delay = defaults.object(forKey: "island.hoverDelay") as? Double ?? IslandDesign.Motion.hoverDelay
        hoverDelay = delay.isFinite ? min(IslandDesign.Motion.maximumHoverDelay, max(IslandDesign.Motion.minimumHoverDelay, delay)) : IslandDesign.Motion.hoverDelay
    }
}
