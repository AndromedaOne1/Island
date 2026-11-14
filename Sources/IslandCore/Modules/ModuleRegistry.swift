import Combine

@MainActor
public final class ModuleRegistry: ObservableObject {
    @Published public private(set) var enabledIDs: Set<String> = []
    @Published public private(set) var selectedModuleID: String?
    public private(set) var modules: [any IslandModule] = []
    private var subscriptions: [String: AnyCancellable] = [:]

    public init() {}

    public var activeModules: [any IslandModule] {
        modules.filter { enabledIDs.contains($0.id) && $0.state == .active }
            .sorted { $0.priority == $1.priority ? $0.id < $1.id : $0.priority > $1.priority }
    }

    public var activeModule: (any IslandModule)? { activeModules.first }

    public var expandedModule: (any IslandModule)? {
        activeModules.first { $0.id == selectedModuleID } ?? activeModule
    }

    @discardableResult
    public func select(_ id: String) -> Bool {
        guard activeModules.contains(where: { $0.id == id }) else { return false }
        selectedModuleID = id
        return true
    }

    public func cycle(by offset: Int) {
        let active = activeModules
        guard !active.isEmpty else { return }
        let current = active.firstIndex { $0.id == expandedModule?.id } ?? 0
        let next = (current + offset % active.count + active.count) % active.count
        select(active[next].id)
    }

    public func beginExpandedPresentation() { selectedModuleID = nil }

    private func reconcileSelection() {
        if let selectedModuleID, !activeModules.contains(where: { $0.id == selectedModuleID }) {
            self.selectedModuleID = nil
        }
    }

    @discardableResult
    public func register(_ module: any IslandModule, enabled: Bool = true) -> Bool {
        guard !modules.contains(where: { $0.id == module.id }) else { return false }
        objectWillChange.send()
        modules.append(module)
        subscriptions[module.id] = module.objectWillChange.sink { [weak self] _ in
            // ObservableObject sends before its mutation. Forward on the next
            // actor turn so selection reads the updated activity and priority.
            Task { @MainActor [weak self] in
                self?.reconcileSelection()
                self?.objectWillChange.send()
            }
        }
        setEnabled(enabled, for: module.id)
        return true
    }

    public func setEnabled(_ enabled: Bool, for id: String) {
        guard let module = modules.first(where: { $0.id == id }), enabledIDs.contains(id) != enabled else { return }
        if enabled {
            enabledIDs.insert(id)
            module.start()
        } else {
            enabledIDs.remove(id)
            module.stop()
        }
        reconcileSelection()
    }

    public func stopAll() {
        for id in enabledIDs.sorted() { setEnabled(false, for: id) }
    }
}
