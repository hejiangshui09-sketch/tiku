import SwiftUI

// MARK: - 外观模式

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - 全局主题色

enum AppTint: String, CaseIterable, Identifiable {
    case indigo, blue, teal, mint, green, orange, pink, purple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indigo: "靛蓝"
        case .blue: "海蓝"
        case .teal: "湖绿"
        case .mint: "薄荷"
        case .green: "草绿"
        case .orange: "暖橙"
        case .pink: "樱粉"
        case .purple: "雾紫"
        }
    }

    var color: Color {
        switch self {
        case .indigo: .indigo
        case .blue: .blue
        case .teal: .teal
        case .mint: .mint
        case .green: .green
        case .orange: .orange
        case .pink: .pink
        case .purple: .purple
        }
    }
}

// MARK: - 阅读主题

enum ReadingTheme: String, CaseIterable, Identifiable {
    case standard, paper, sepia, night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "默认"
        case .paper: "纸张"
        case .sepia: "护眼"
        case .night: "夜间"
        }
    }

    var background: Color {
        switch self {
        case .standard: Color(uiColor: .systemGroupedBackground)
        case .paper: Color(red: 0.98, green: 0.97, blue: 0.95)
        case .sepia: Color(red: 0.96, green: 0.93, blue: 0.85)
        case .night: Color(red: 0.09, green: 0.09, blue: 0.11)
        }
    }

    var cardBackground: Color {
        switch self {
        case .standard: Color(uiColor: .secondarySystemGroupedBackground)
        case .paper: .white
        case .sepia: Color(red: 0.99, green: 0.97, blue: 0.91)
        case .night: Color(red: 0.14, green: 0.14, blue: 0.17)
        }
    }

    var textColor: Color {
        switch self {
        case .standard: .primary
        case .paper: Color(red: 0.15, green: 0.14, blue: 0.13)
        case .sepia: Color(red: 0.27, green: 0.21, blue: 0.13)
        case .night: Color(white: 0.88)
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .standard: .secondary
        case .paper: Color(red: 0.42, green: 0.41, blue: 0.39)
        case .sepia: Color(red: 0.48, green: 0.40, blue: 0.29)
        case .night: Color(white: 0.6)
        }
    }

    /// 夜间主题需要强制深色 UI 控件。
    var forcedColorScheme: ColorScheme? {
        switch self {
        case .night: .dark
        case .paper, .sepia: .light
        case .standard: nil
        }
    }
}

// MARK: - 阅读字体

enum ReadingFontDesign: String, CaseIterable, Identifiable {
    case system, serif, rounded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "系统"
        case .serif: "衬线"
        case .rounded: "圆体"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: .default
        case .serif: .serif
        case .rounded: .rounded
        }
    }
}

// MARK: - 偏好存储

@MainActor
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private let defaults = UserDefaults.standard

    @Published var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: "pref.appearance") }
    }

    @Published var tint: AppTint {
        didSet { defaults.set(tint.rawValue, forKey: "pref.tint") }
    }

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: "pref.haptics") }
    }

    @Published var dailyGoalMinutes: Int {
        didSet { defaults.set(dailyGoalMinutes, forKey: "pref.dailyGoal") }
    }

    // 阅读偏好
    @Published var readingFontScale: Double {
        didSet { defaults.set(readingFontScale, forKey: "pref.reading.fontScale") }
    }

    @Published var readingLineSpacing: Double {
        didSet { defaults.set(readingLineSpacing, forKey: "pref.reading.lineSpacing") }
    }

    @Published var readingFontDesign: ReadingFontDesign {
        didSet { defaults.set(readingFontDesign.rawValue, forKey: "pref.reading.fontDesign") }
    }

    @Published var readingTheme: ReadingTheme {
        didSet { defaults.set(readingTheme.rawValue, forKey: "pref.reading.theme") }
    }

    private init() {
        appearance = AppearanceMode(rawValue: defaults.string(forKey: "pref.appearance") ?? "") ?? .system
        tint = AppTint(rawValue: defaults.string(forKey: "pref.tint") ?? "") ?? .indigo
        hapticsEnabled = defaults.object(forKey: "pref.haptics") as? Bool ?? true
        dailyGoalMinutes = defaults.object(forKey: "pref.dailyGoal") as? Int ?? 30
        readingFontScale = defaults.object(forKey: "pref.reading.fontScale") as? Double ?? 1.0
        readingLineSpacing = defaults.object(forKey: "pref.reading.lineSpacing") as? Double ?? 6
        readingFontDesign = ReadingFontDesign(rawValue: defaults.string(forKey: "pref.reading.fontDesign") ?? "") ?? .system
        readingTheme = ReadingTheme(rawValue: defaults.string(forKey: "pref.reading.theme") ?? "") ?? .standard
    }
}
