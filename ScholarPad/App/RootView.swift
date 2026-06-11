import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $model.selectedSection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 290)
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
            .background(ScholarTheme.page)
        }
        .navigationSplitViewStyle(.balanced)
        .alert("学程", isPresented: Binding(
            get: { model.notice != nil },
            set: { if !$0 { model.notice = nil } }
        )) {
            Button("好") { model.notice = nil }
        } message: {
            Text(model.notice ?? "")
        }
        .overlay {
            if model.isLoading {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    SwiftUI.ProgressView("正在准备课程…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .transition(.opacity)
            }
        }
    }
}
