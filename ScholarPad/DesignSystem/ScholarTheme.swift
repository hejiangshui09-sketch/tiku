import SwiftUI
import UIKit

// MARK: - 设计令牌

enum ScholarTheme {
    // 背景层级
    static let page = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevated = Color(uiColor: .tertiarySystemGroupedBackground)

    // 语义色
    static let primary = Color.indigo
    static let secondary = Color.cyan
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red

    // 圆角
    static let heroRadius: CGFloat = 28
    static let cornerRadius: CGFloat = 22
    static let compactRadius: CGFloat = 15
    static let chipRadius: CGFloat = 10

    // 间距
    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let pagePadding: CGFloat = 28
    }

    // 动效
    enum Motion {
        static let snappy = Animation.snappy(duration: 0.32)
        static let smooth = Animation.smooth(duration: 0.4)
        static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.72)
    }
}

// MARK: - 字体梯度

enum ScholarFont {
    static func display(_ scale: Double = 1, design: Font.Design = .rounded) -> Font {
        .system(size: 34 * scale, weight: .bold, design: design)
    }
    static func title(_ scale: Double = 1, design: Font.Design = .default) -> Font {
        .system(size: 26 * scale, weight: .bold, design: design)
    }
    static func heading(_ scale: Double = 1, design: Font.Design = .default) -> Font {
        .system(size: 21 * scale, weight: .bold, design: design)
    }
    static func body(_ scale: Double = 1, design: Font.Design = .default) -> Font {
        .system(size: 17 * scale, weight: .regular, design: design)
    }
    static func callout(_ scale: Double = 1, design: Font.Design = .default) -> Font {
        .system(size: 15.5 * scale, weight: .regular, design: design)
    }
    static func caption(_ scale: Double = 1) -> Font {
        .system(size: 12.5 * scale, weight: .medium)
    }
}

// MARK: - 课程主题色

extension CourseAccent {
    var color: Color {
        switch self {
        case .indigo: .indigo
        case .cyan: .cyan
        case .coral: .orange
        case .violet: .purple
        case .mint: .mint
        case .rose: .pink
        case .amber: Color(red: 0.95, green: 0.66, blue: 0.12)
        case .teal: .teal
        case .blue: .blue
        }
    }

    var title: String {
        switch self {
        case .indigo: "靛蓝"
        case .cyan: "青色"
        case .coral: "珊瑚"
        case .violet: "紫罗兰"
        case .mint: "薄荷"
        case .rose: "玫瑰"
        case .amber: "琥珀"
        case .teal: "湖绿"
        case .blue: "海蓝"
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.66)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 用于课程封面的双色渐变，比单色更有“封面感”。
    var coverGradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.92), companion.opacity(0.86)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var companion: Color {
        switch self {
        case .indigo: .purple
        case .cyan: .blue
        case .coral: .pink
        case .violet: .indigo
        case .mint: .teal
        case .rose: .orange
        case .amber: .orange
        case .teal: .cyan
        case .blue: .indigo
        }
    }

    /// 封面装饰符号，让每门课程封面有差异。
    var coverSymbol: String {
        switch self {
        case .indigo: "function"
        case .cyan: "atom"
        case .coral: "flame"
        case .violet: "sparkles"
        case .mint: "leaf"
        case .rose: "heart.text.square"
        case .amber: "sun.max"
        case .teal: "drop"
        case .blue: "globe.asia.australia"
        }
    }
}

// MARK: - 卡片

struct ScholarCardModifier: ViewModifier {
    var padding: CGFloat = 20
    var radius: CGFloat = ScholarTheme.cornerRadius
    var shadowed = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ScholarTheme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.primary.opacity(0.055), lineWidth: 1)
            }
            .shadow(
                color: shadowed ? Color.black.opacity(0.05) : .clear,
                radius: 14, y: 6
            )
    }
}

extension View {
    func scholarCard(padding: CGFloat = 20, radius: CGFloat = ScholarTheme.cornerRadius, shadowed: Bool = true) -> some View {
        modifier(ScholarCardModifier(padding: padding, radius: radius, shadowed: shadowed))
    }
}

// MARK: - 按钮按压反馈

struct ScalingButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.975

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScalingButtonStyle {
    static var scaling: ScalingButtonStyle { ScalingButtonStyle() }
}

// MARK: - 触觉反馈

@MainActor
enum Haptics {
    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: "pref.haptics") as? Bool ?? true
    }

    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - 标题区

struct SectionHeading: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - 进度环（带动画）

struct ProgressRing: View {
    let value: Double
    var size: CGFloat = 56
    var lineWidth: CGFloat = 7
    var color: Color = ScholarTheme.primary
    var showsLabel = true

    @State private var animated: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(animated, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: size * 0.22, weight: .bold))
                    .monospacedDigit()
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.smooth(duration: 0.8)) { animated = value }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.smooth(duration: 0.5)) { animated = newValue }
        }
        .accessibilityLabel("完成度")
        .accessibilityValue(Text(value, format: .percent))
    }
}

// MARK: - 指标卡

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .scholarCard(padding: 16)
    }
}

// MARK: - 胶囊标签

struct InfoChip: View {
    let text: String
    var symbol: String?
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - 空状态

struct EmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
            }
        } description: {
            Text(detail)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 顶部 Toast 提示

struct ToastView: View {
    let message: String
    var isSuccess = true

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isSuccess ? .green : .orange)
            Text(message)
                .font(.subheadline.weight(.medium))
                .lineLimit(3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }
}
