import Combine
import IslandCore
import SwiftUI
import Testing

@MainActor private final class TestModule: IslandModule {
    let id: String
    var title: String { id }
    @Published var priority: Int
    @Published var isActive: Bool
    private(set) var starts = 0
    private(set) var stops = 0

    init(_ id: String, priority: Int, active: Bool = true) {
        self.id = id
        self.priority = priority
        isActive = active
    }
    func compactView(for position: CompactPosition) -> AnyView { AnyView(EmptyView()) }
    func expandedView() -> AnyView { AnyView(EmptyView()) }
    func start() { starts += 1 }
    func stop() { stops += 1 }
}

@Test @MainActor func priorityAndStableIdentifierSelectActiveModule() {
    let registry = ModuleRegistry()
    let z = TestModule("z", priority: 10)
    let a = TestModule("a", priority: 10)
    let urgent = TestModule("urgent", priority: 20, active: false)
    registry.register(z)
    registry.register(a)
    registry.register(urgent)
    #expect(registry.activeModule?.id == "a")
    urgent.isActive = true
    #expect(registry.activeModule?.id == "urgent")
    registry.setEnabled(false, for: urgent.id)
    #expect(registry.activeModule?.id == "a")
    a.priority = 0
    #expect(registry.activeModule?.id == "z")
}

@Test @MainActor func moduleLifecycleIsIdempotentAndRejectsDuplicateIDs() {
    let registry = ModuleRegistry()
    let module = TestModule("timer", priority: 1)
    #expect(registry.register(module, enabled: false))
    #expect(module.starts == 0)
    #expect(!registry.register(TestModule("timer", priority: 100)))
    registry.setEnabled(true, for: module.id)
    registry.setEnabled(true, for: module.id)
    #expect(module.starts == 1)
    registry.setEnabled(false, for: module.id)
    registry.setEnabled(false, for: module.id)
    #expect(module.stops == 1)
    registry.setEnabled(true, for: module.id)
    registry.stopAll()
    registry.stopAll()
    #expect(module.starts == 2)
    #expect(module.stops == 2)
    #expect(registry.activeModule == nil)
}

@Test @MainActor func moduleUpdatesReachRegistryObservers() async throws {
    let registry = ModuleRegistry()
    let module = TestModule("battery", priority: 1, active: false)
    registry.register(module)
    var notifications = 0
    let subscription = registry.objectWillChange.sink { notifications += 1 }
    module.isActive = true
    try await Task.sleep(for: .milliseconds(30))
    #expect(notifications > 0)
    #expect(registry.activeModule?.id == module.id)
    withExtendedLifetime(subscription) {}
}
