import Combine

@MainActor
public final class ModuleRegistry: ObservableObject {
    @Published public private(set) var enabledIDs: Set<String> = []
    public private(set) var modules: [any IslandModule] = []
    private var subscriptions: [String: AnyCancellable] = [:]

    public init() {}

    public var activeModule: (any IslandModule)? {
        modules.filter { enabledIDs.contains($0.id) && $0.isActive }
            .sorted { $0.priority == $1.priority ? $0.id < $1.id : $0.priority > $1.priority }
            .first
    }

    @discardableResult
    public func register(_ module: any IslandModule, enabled: Bool = true) -> Bool {
        guard !modules.contains(where: { $0.id == module.id }) else { return false }
        objectWillChange.send()
        modules.append(module)
        subscriptions[module.id] = module.objectWillChange.sink { [weak self] _ in
            // ObservableObject sends before its mutation. Forward on the next
            // actor turn so selection reads the updated activity and priority.
            Task { @MainActor [weak self] in self?.objectWillChange.send() }
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
    }

    public func stopAll() {
        for id in enabledIDs.sorted() { setEnabled(false, for: id) }
    }
}
