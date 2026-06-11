import SwiftUI

enum ScholarTheme {
    static let page = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevated = Color(uiColor: .tertiarySystemGroupedBackground)
    static let primary = Color.indigo
    static let secondary = Color.cyan
    static let success = Color.green
    static let warning = Color.orange
    static let cornerRadius: CGFloat = 22
    static let compactRadius: CGFloat = 15
}

extension CourseAccent {
    var color: Color {
        switch self {
        case .indigo: .indigo
        case .cyan: .cyan
        case .coral: .orange
        case .violet: .purple
        case .mint: .mint
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.68)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct ScholarCardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ScholarTheme.card, in: RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous)
                    .stroke(.primary.opacity(0.055), lineWidth: 1)
            }
    }
}

extension View {
    func scholarCard(padding: CGFloat = 20) -> some View {
        modifier(ScholarCardModifier(padding: padding))
    }
}

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

struct ProgressRing: View {
    let value: Double
    var size: CGFloat = 56
    var lineWidth: CGFloat = 7
    var color: Color = ScholarTheme.primary

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(value, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(value, format: .percent.precision(.fractionLength(0)))
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityLabel("完成度")
        .accessibilityValue(Text(value, format: .percent))
    }
}

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
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .scholarCard(padding: 16)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
            }
        } description: {
            Text(detail)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
