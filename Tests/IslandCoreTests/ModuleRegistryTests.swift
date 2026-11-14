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

@Test @MainActor func expandedSelectionDoesNotChangeCompactPriority() {
    let registry = ModuleRegistry()
    registry.register(TestModule("music", priority: 100))
    registry.register(TestModule("timer", priority: 200))
    registry.register(TestModule("idle", priority: 300, active: false))
    #expect(registry.activeModules.map(\.id) == ["timer", "music"])
    #expect(!registry.select("idle"))
    #expect(!registry.select("missing"))
    #expect(registry.select("music"))
    #expect(registry.expandedModule?.id == "music")
    #expect(registry.activeModule?.id == "timer")
    registry.beginExpandedPresentation()
    #expect(registry.expandedModule?.id == "timer")
}

@Test @MainActor func moduleCyclingWrapsAndHandlesEmptyAndSingleLists() {
    let registry = ModuleRegistry()
    registry.cycle(by: -1)
    #expect(registry.expandedModule == nil)
    registry.register(TestModule("a", priority: 2))
    registry.cycle(by: 1)
    #expect(registry.expandedModule?.id == "a")
    registry.register(TestModule("b", priority: 1))
    registry.cycle(by: 1)
    #expect(registry.expandedModule?.id == "b")
    registry.cycle(by: 1)
    #expect(registry.expandedModule?.id == "a")
    registry.cycle(by: -1)
    #expect(registry.expandedModule?.id == "b")
    registry.cycle(by: Int.min)
    #expect(registry.expandedModule?.id == "b")
}

@Test @MainActor func selectedModuleFallsBackAfterIdleOrDisable() async throws {
    let registry = ModuleRegistry()
    let music = TestModule("music", priority: 100)
    let timer = TestModule("timer", priority: 200)
    registry.register(music)
    registry.register(timer)
    registry.select(music.id)
    timer.priority = 300
    #expect(registry.expandedModule?.id == music.id)
    music.isActive = false
    #expect(registry.expandedModule?.id == timer.id)
    try await Task.sleep(for: .milliseconds(30))
    #expect(registry.selectedModuleID == nil)
    registry.setEnabled(false, for: timer.id)
    #expect(registry.expandedModule == nil)
    #expect(registry.activeModules.isEmpty)
    #expect(music.state == .idle)
}
