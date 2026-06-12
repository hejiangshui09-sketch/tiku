import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var prefs: AppPreferences
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
                        LinearGradient(
                            colors: [prefs.tint.color, prefs.tint.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .shadow(color: prefs.tint.color.opacity(0.3), radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text("知识学习库")
                        .font(.headline.weight(.bold))
                    Text("把每本书整理成自己的知识")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider().opacity(0.4)
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill((model.network.isConnected ? Color.green : Color.orange).opacity(0.18))
                            .frame(width: 16, height: 16)
                        Circle()
                            .fill(model.network.isConnected ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                    }
                    Text(model.network.isConnected ? "\(model.network.connectionName) · 内容可同步" : "离线学习模式")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(14)
            }
            .background(.thinMaterial)
        }
        .navigationTitle("知识学习库")
    }

    private func sidebarButton(_ section: AppSection) -> some View {
        Button {
            Haptics.selection()
            model.activateSection(section)
        } label: {
            SidebarRow(section: section, isSelected: selection == section, tint: prefs.tint.color)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selection == section ? prefs.tint.color.opacity(0.14) : Color.clear)
        )
        .accessibilityAddTraits(selection == section ? .isSelected : [])
    }
}

private struct SidebarRow: View {
    let section: AppSection
    let isSelected: Bool
    let tint: Color

    var body: some View {
        Label {
            Text(section.title)
                .font(.body.weight(isSelected ? .semibold : .medium))
        } icon: {
            Image(systemName: isSelected ? section.selectedSymbol : section.symbol)
                .foregroundStyle(isSelected ? tint : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(.vertical, 5)
    }
}
