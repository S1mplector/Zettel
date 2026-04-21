import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettingKey.sidebarDensity) private var sidebarDensityRawValue = SidebarDensity.comfortable.rawValue
    @AppStorage(AppSettingKey.showSidebarChildCounts) private var showSidebarChildCounts = true
    @AppStorage(AppSettingKey.showTreeGuides) private var showTreeGuides = true
    @AppStorage(AppSettingKey.showNodeMetadata) private var showNodeMetadata = true
    @AppStorage(AppSettingKey.autoExpandSelectionPath) private var autoExpandSelectionPath = true

    var body: some View {
        Form {
            Section("Sidebar") {
                Picker("Density", selection: $sidebarDensityRawValue) {
                    ForEach(SidebarDensity.allCases) { density in
                        Text(density.title).tag(density.rawValue)
                    }
                }

                Toggle("Show child counts in the tree", isOn: $showSidebarChildCounts)
                Toggle("Show vertical guide rails", isOn: $showTreeGuides)
            }

            Section("Editor") {
                Toggle("Show created and updated timestamps", isOn: $showNodeMetadata)
            }

            Section("Behavior") {
                Toggle("Auto-expand ancestors when selecting nodes", isOn: $autoExpandSelectionPath)

                Text("Changes apply immediately to the current window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 480)
    }
}
