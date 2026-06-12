import SwiftUI

@main
struct ScholarPadApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var prefs = AppPreferences.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(prefs)
                .task {
                    await model.bootstrap()
                }
        }
        .commands {
            CommandMenu("学习") {
                Button("学习首页") { model.activateSection(.home) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("我的书柜") { model.activateSection(.courses) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("题目练习") { model.activateSection(.practice) }
                    .keyboardShortcut("3", modifiers: .command)
                Divider()
                Button("全局搜索") { model.activateSection(.search) }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}
