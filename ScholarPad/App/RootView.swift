import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var prefs: AppPreferences
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $model.selectedSection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 252, max: 290)
        } detail: {
            Group {
                switch model.selectedSection {
                case .home:
                    DashboardView()
                case .courses:
                    CourseCatalogView()
                case .online:
                    OnlineLibraryView()
                case .practice:
                    PracticeHubView()
                case .search:
                    GlobalSearchView()
                case .saved:
                    SavedItemsView()
                case .notes:
                    NotesView()
                case .progress:
                    LearningProgressView()
                case .settings:
                    SettingsView()
                }
            }
            .id("\(model.selectedSection.rawValue)-\(model.navigationResetID.uuidString)")
            .background(ScholarTheme.page)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(prefs.tint.color)
        .preferredColorScheme(prefs.appearance.colorScheme)
        .onChange(of: model.notice) { _, notice in
            guard let notice else { return }
            showToast(notice)
            model.notice = nil
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                ToastView(
                    message: toastMessage,
                    isSuccess: !toastMessage.contains("失败") && !toastMessage.contains("无法") && !toastMessage.contains("错误")
                )
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if model.isLoading {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    SwiftUI.ProgressView("正在准备课程…")
                        .padding(26)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 24, y: 10)
                }
                .transition(.opacity)
            }
        }
        .animation(ScholarTheme.Motion.snappy, value: toastMessage)
        .animation(.easeInOut(duration: 0.2), value: model.isLoading)
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }
}
