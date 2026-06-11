import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selection: AppSection

    var body: some View {
        List {
            Section {
                ForEach([AppSection.home, .courses, .online, .practice, .search]) { section in
                    sidebarButton(section)
                }
            }

            Section("学习空间") {
                ForEach([AppSection.saved, .notes, .progress]) { section in
                    sidebarButton(section)
                }
            }

            Section {
                sidebarButton(.settings)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("学程")
                        .font(.headline.weight(.bold))
                    Text("让每次学习都有进展")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Circle()
                    .fill(model.network.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(model.network.isConnected ? "\(model.network.connectionName) · 内容可同步" : "离线学习模式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(14)
            .background(.thinMaterial)
        }
        .navigationTitle("学程")
    }

    private func sidebarButton(_ section: AppSection) -> some View {
        Button {
            selection = section
        } label: {
            SidebarRow(section: section)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selection == section ? Color.accentColor.opacity(0.14) : Color.clear)
        )
        .accessibilityAddTraits(selection == section ? .isSelected : [])
    }
}

private struct SidebarRow: View {
    let section: AppSection

    var body: some View {
        Label(section.title, systemImage: section.symbol)
            .font(.body.weight(.medium))
            .padding(.vertical, 5)
    }
}
