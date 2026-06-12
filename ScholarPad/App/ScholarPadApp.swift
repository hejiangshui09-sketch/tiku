import SwiftUI

@main
struct ScholarPadApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task {
                    await model.bootstrap()
                }
        }
        .commands {
            CommandMenu("学习") {
                Button("学习首页") { model.selectedSection = .home }
                    .keyboardShortcut("1", modifiers: .command)
                Button("我的课程") { model.selectedSection = .courses }
                    .keyboardShortcut("2", modifiers: .command)
                Button("题目练习") { model.selectedSection = .practice }
                    .keyboardShortcut("3", modifiers: .command)
                Divider()
                Button("全局搜索") { model.selectedSection = .search }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}
