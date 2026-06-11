import Charts
import SwiftUI

struct LearningProgressView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    SectionHeading(title: "学习报告", subtitle: "用清晰的数据看见积累")
                    metricGrid
                    weeklyChart
                    courseProgress
                }
                .padding(28)
                .frame(maxWidth: 1320, alignment: .leading)
            }
            .navigationTitle("学习报告")
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
            MetricTile(title: "累计学习", value: studyTime, symbol: "clock.fill", color: .indigo)
            MetricTile(title: "连续天数", value: "\(model.streakDays) 天", symbol: "flame.fill", color: .orange)
            MetricTile(title: "答题数量", value: "\(model.attemptedQuestions)", symbol: "checkmark.seal.fill", color: .cyan)
            MetricTile(title: "答题正确率", value: accuracy, symbol: "scope", color: .green)
            MetricTile(title: "待复习", value: "\(model.dueReviewQuestions().count) 题", symbol: "arrow.triangle.2.circlepath", color: .orange)
            MetricTile(title: "学习笔记", value: "\(model.notes.count) 条", symbol: "note.text", color: .purple)
        }
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "近 7 天学习时长", subtitle: "分钟")
            Chart {
                ForEach(Array(model.dailyMinutes().enumerated()), id: \.offset) { item in
                    BarMark(
                        x: .value("日期", item.element.0, unit: .day),
                        y: .value("分钟", item.element.1)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .cyan], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(6)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 250)
        }
        .scholarCard()
    }

    private var courseProgress: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "课程完成度", subtitle: "按章节知识模块统计")
            ForEach(model.courses) { course in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(course.title)
                            .font(.headline)
                        Spacer()
                        Text(model.courseCompletion(course), format: .percent.precision(.fractionLength(0)))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(course.accent.color)
                    }
                    ProgressView(value: model.courseCompletion(course))
                        .tint(course.accent.color)
                }
                .padding(.vertical, 6)
            }
        }
        .scholarCard()
    }

    private var studyTime: String {
        let minutes = Int(model.totalStudySeconds / 60)
        return minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分" : "\(minutes) 分钟"
    }

    private var accuracy: String {
        guard model.attemptedQuestions > 0 else { return "暂无" }
        return (Double(model.correctQuestions) / Double(model.attemptedQuestions))
            .formatted(.percent.precision(.fractionLength(0)))
    }
}
