import IslandCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: ShellSettings
    @ObservedObject var panel: IslandPanelController
    @ObservedObject var loginItem: LoginItemController

    var body: some View {
        Form {
            Section("Overlay") {
                Toggle("Show Island", isOn: $settings.isVisible)
                Picker("Display", selection: $settings.selectedDisplayID) {
                    Text("Automatic (prefer notch)").tag("")
                    ForEach(panel.screens, id: \.id) { screen in
                        Text(screen.name + (screen.hasNotch ? " — notch" : " — pill")).tag(screen.id)
                    }
                    if !settings.selectedDisplayID.isEmpty,
                       !panel.screens.contains(where: { $0.id == settings.selectedDisplayID }) {
                        Text("Disconnected display (using automatic)").tag(settings.selectedDisplayID)
                    }
                }
                HStack {
                    Text("Hover delay")
                    Slider(value: $settings.hoverDelay, in: 0.05...1.5, step: 0.05)
                    Text(settings.hoverDelay, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit().frame(width: 40)
                    Text("s")
                }
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(get: { loginItem.isEnabled }, set: loginItem.setEnabled))
                if let message = loginItem.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Hover over the notch to expand. Click to pin; click again or outside to dismiss. Use the menu bar to preview compact wings.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
    }
}
