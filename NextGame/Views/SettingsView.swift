import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            Text("Pick each widget's team from the widget's edit menu.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(minWidth: 360, minHeight: 140)
    }
}
