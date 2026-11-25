import AppKit
import ClearDeskCore
import SwiftUI

struct FileGridView: View {
    @Bindable var viewModel: ClearDeskViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 118, maximum: 140), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.selectedSection == .all {
                    let desktopItems = viewModel.filteredItems.filter { $0.location == .desktop }
                    let vaultItems = viewModel.filteredItems.filter { $0.location == .vault }

                    sectionBlock(title: "On Desktop", emptyText: "Desktop is clean", items: desktopItems)
                    Divider()
                    sectionBlock(title: "In Vault", emptyText: "Swept items appear here", items: vaultItems)
                } else {
                    sectionBlock(
                        title: viewModel.selectedSection.rawValue,
                        emptyText: "No items",
                        items: viewModel.filteredItems
                    )
                }
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedItemID = nil
        }
        .onKeyPress(.space) {
            if let item = viewModel.selectedItem {
                viewModel.quickLook(item)
                return .handled
            }
            return .ignored
        }
    }

    @ViewBuilder
    private func sectionBlock(title: String, emptyText: String, items: [DeskItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            if items.isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(.quaternary)
                    )
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(items) { item in
                        DeskItemTile(
                            item: item,
                            isSelected: viewModel.selectedItemID == item.id,
                            onSelect: { viewModel.selectedItemID = item.id },
                            onOpen: { viewModel.openItem(item) },
                            onQuickLook: { viewModel.quickLook(item) },
                            onReveal: { viewModel.revealInFinder(item) },
                            onMoveToVault: { viewModel.moveToVault(item) },
                            onRestore: { viewModel.restoreToDesktop(item) },
                            onTogglePin: { viewModel.togglePin(item) }
                        )
                    }
                }
            }
        }
    }
}

private struct DeskItemTile: View {
    let item: DeskItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onQuickLook: () -> Void
    let onReveal: () -> Void
    let onMoveToVault: () -> Void
    let onRestore: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .opacity(item.isSettling ? 0.5 : 1.0)

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tint)
                        .padding(4)
                        .background(.regularMaterial, in: Circle())
                        .offset(x: 4, y: -2)
                }
            }

            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )

            Text(item.isSettling ? "Syncing…" : item.formattedSize)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onOpen()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
        .contextMenu {
            Button("Open", action: onOpen)
            Button("Quick Look", action: onQuickLook)
            Button("Reveal in Finder", action: onReveal)
            Divider()
            if item.location == .desktop {
                Button("Move to Vault", action: onMoveToVault)
                    .disabled(item.isSettling)
                Button(item.isPinned ? "Unpin from Desktop" : "Pin to Desktop", action: onTogglePin)
            } else {
                Button("Restore to Desktop", action: onRestore)
            }
        }
    }
}
