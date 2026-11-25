import SwiftUI

@main
struct ClearDeskApp: App {
    @State private var viewModel = ClearDeskViewModel()

    var body: some Scene {
        WindowGroup("ClearDesk") {
            MainContentView(viewModel: viewModel)
                .frame(minWidth: 740, minHeight: 480)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.desktopCount == 0 ? "Desktop is clean" : "\(viewModel.desktopCount) item(s) on Desktop")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                Button("Sweep Desktop (\(viewModel.sweepableDesktopCount))") {
                    viewModel.sweepDesktop()
                }
                .disabled(viewModel.sweepableDesktopCount == 0)

                if viewModel.canUndo {
                    Button("Undo Last Sweep") {
                        viewModel.undoLastSweep()
                    }
                }
                Divider()
                Button("Quit ClearDesk") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(6)
        } label: {
            Label(
                "ClearDesk",
                systemImage: viewModel.desktopCount == 0 ? "checkmark.circle" : "menubar.dock.rectangle"
            )
        }
    }
}

private struct MainContentView: View {
    @Bindable var viewModel: ClearDeskViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            ZStack(alignment: .bottom) {
                FileGridView(viewModel: viewModel)
                    .navigationTitle(viewModel.selectedSection.rawValue)
                    .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                viewModel.sweepDesktop()
                            } label: {
                                Text(
                                    viewModel.sweepableDesktopCount > 0
                                        ? "Sweep Desktop (\(viewModel.sweepableDesktopCount))"
                                        : "Desktop Clean"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.sweepableDesktopCount == 0)
                        }
                    }

                if let hud = viewModel.hudMessage {
                    HStack(spacing: 12) {
                        Text(hud)
                            .font(.callout)
                        if viewModel.canUndo {
                            Button("Undo") {
                                viewModel.undoLastSweep()
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: viewModel.hudMessage)
        }
        .alert(
            "ClearDesk",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
        )
    }
}
