import Foundation
import IslandCore
import Testing

@Test @MainActor func shellPreferencesPersistAndInvalidDelayIsClamped() throws {
    let suite = "IslandTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(-10.0, forKey: "island.hoverDelay")
    let settings = ShellSettings(defaults: defaults)
    #expect(settings.isVisible)
    #expect(settings.hoverDelay == 0.02)
    settings.isVisible = false
    settings.selectedDisplayID = "external"
    settings.hoverDelay = 0.4
    let restored = ShellSettings(defaults: defaults)
    #expect(!restored.isVisible)
    #expect(restored.selectedDisplayID == "external")
    #expect(restored.hoverDelay == 0.4)
}
