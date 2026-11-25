import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: ClearDeskViewModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $viewModel.selectedSection) {
                Section("Locations") {
                    sidebarRow(.all)
                    sidebarRow(.desktop)
                    sidebarRow(.vault)
                }

                Section("Kinds") {
                    sidebarRow(.folders)
                    sidebarRow(.documents)
                    sidebarRow(.images)
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Text("Auto-Sweep")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { viewModel.autoSweepEnabled },
                        set: { viewModel.setAutoSweep($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
    }

    @ViewBuilder
    private func sidebarRow(_ section: SidebarSection) -> some View {
        HStack {
            Label(section.rawValue, systemImage: section.symbolName)
            Spacer()
            let count = viewModel.count(for: section)
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .tag(section)
    }
}
