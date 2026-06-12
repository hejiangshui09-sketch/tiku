import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var prefs: AppPreferences

    private var continueCourse: Course? {
        // 优先最近学习过的课程，其次完成度最高的课程
        model.courses
            .filter { model.lastStudied($0) != nil }
            .max { (model.lastStudied($0) ?? .distantPast) < (model.lastStudied($1) ?? .distantPast) }
            ?? model.courses.max { model.courseCompletion($0) < model.courseCompletion($1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    welcomeHero
                    metrics

                    HStack(alignment: .top, spacing: 18) {
                        dailyGoalCard
                        WeeklyHeatmap(dailyMinutes: model.dailyMinutes(days: 28), tint: prefs.tint.color)
                            .frame(maxWidth: .infinity)
                    }

                    if !model.dueReviewQuestions().isEmpty {
                        reviewBanner
                    }

                    if let course = continueCourse {
                        SectionHeading(title: "继续学习", subtitle: "沿着上次的进度继续，不必重新寻找")
                        ContinueCourseCard(course: course)
                    }

                    SectionHeading(title: "课程总览", subtitle: "知识、练习和复习统一组织")
                    courseGrid
                }
                .padding(ScholarTheme.Spacing.pagePadding)
                .frame(maxWidth: 1320, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("学习首页")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.selectedSection = .search
                    } label: {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
                }
            }
        }
    }

    // MARK: - 欢迎横幅

    private var welcomeHero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 13) {
                Text(greeting)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                Text(heroLine)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("已连续学习 \(model.streakDays) 天 · 累计 \(formattedStudyTime)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            Spacer()
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 78))
                .foregroundStyle(.white.opacity(0.92))
                .symbolRenderingMode(.hierarchical)
                .padding(.trailing, 24)
        }
        .padding(30)
        .background(
            LinearGradient(
                colors: [prefs.tint.color, prefs.tint.color.opacity(0.78), prefs.tint.color.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: ScholarTheme.heroRadius, style: .continuous)
        )
        .shadow(color: prefs.tint.color.opacity(0.22), radius: 24, y: 12)
    }

    private var heroLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if model.streakDays >= 7 { return "连续 \(model.streakDays) 天，\n习惯正在养成。" }
        if hour < 9 { return "清晨的专注，\n是一天最好的开始。" }
        if hour >= 21 { return "睡前回顾一遍，\n记忆更牢固。" }
        return "今天，继续把知识\n变成真正的掌握。"
    }

    // MARK: - 指标

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
            MetricTile(title: "累计学习", value: formattedStudyTime, symbol: "clock.fill", color: .indigo)
            MetricTile(title: "已练题目", value: "\(model.attemptedQuestions)", symbol: "checkmark.seal.fill", color: .cyan)
            MetricTile(title: "答题正确率", value: accuracyText, symbol: "scope", color: .green)
            MetricTile(title: "连续学习", value: "\(model.streakDays) 天", symbol: "flame.fill", color: .orange)
        }
    }

    // MARK: - 每日目标

    private var todayMinutes: Double {
        model.dailyMinutes(days: 1).last?.1 ?? 0
    }

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("今日目标", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            HStack(spacing: 18) {
                ProgressRing(
                    value: min(todayMinutes / Double(max(prefs.dailyGoalMinutes, 1)), 1),
                    size: 76,
                    lineWidth: 9,
                    color: prefs.tint.color
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(todayMinutes)) / \(prefs.dailyGoalMinutes) 分钟")
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                    Text(todayMinutes >= Double(prefs.dailyGoalMinutes) ? "今日目标已达成 🎉" : "还差 \(max(0, prefs.dailyGoalMinutes - Int(todayMinutes))) 分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scholarCard(padding: 18)
        .frame(width: 280)
    }

    // MARK: - 复习横幅

    private var reviewBanner: some View {
        NavigationLink {
            ReviewQueueView()
        } label: {
            HStack(spacing: 18) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 5) {
                    Text("今天有 \(model.dueReviewQuestions().count) 道题待复习")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("按间隔复习计划巩固容易遗忘的内容")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("开始复习")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .scholarCard()
        }
        .buttonStyle(.scaling)
    }

    private var courseGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 18)], spacing: 18) {
            ForEach(model.courses) { course in
                NavigationLink {
                    CourseDetailView(course: course)
                } label: {
                    CourseSummaryCard(course: course)
                }
                .buttonStyle(.scaling)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "早上好" : hour < 18 ? "下午好" : "晚上好"
    }

    private var formattedStudyTime: String {
        let minutes = Int(model.totalStudySeconds / 60)
        return minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分" : "\(minutes) 分钟"
    }

    private var accuracyText: String {
        guard model.attemptedQuestions > 0 else { return "尚未答题" }
        return (Double(model.correctQuestions) / Double(model.attemptedQuestions))
            .formatted(.percent.precision(.fractionLength(0)))
    }
}

// MARK: - 近28天学习热力图

struct WeeklyHeatmap: View {
    let dailyMinutes: [(Date, Double)]
    var tint: Color = .indigo

    private var maxMinutes: Double {
        max(dailyMinutes.map(\.1).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("近 4 周学习", systemImage: "square.grid.4x3.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(dailyMinutes.map(\.1).reduce(0, +))) 分钟")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(dailyMinutes.enumerated()), id: \.offset) { _, entry in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(cellColor(entry.1))
                        .aspectRatio(1.6, contentMode: .fit)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(.primary.opacity(0.05), lineWidth: 0.5)
                        }
                }
            }

            HStack(spacing: 6) {
                Text("少")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level == 0 ? ScholarTheme.elevated : tint.opacity(0.2 + level * 0.7))
                        .frame(width: 14, height: 10)
                }
                Text("多")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .scholarCard(padding: 18)
    }

    private func cellColor(_ minutes: Double) -> Color {
        guard minutes > 0 else { return ScholarTheme.elevated }
        let level = min(minutes / maxMinutes, 1)
        return tint.opacity(0.2 + level * 0.7)
    }
}

// MARK: - 继续学习卡片

private struct ContinueCourseCard: View {
    @EnvironmentObject private var model: AppModel
    let course: Course

    private var nextChapter: Chapter? { model.resumeChapter(for: course) }

    var body: some View {
        if let nextChapter {
            NavigationLink {
                LessonReaderView(course: course, chapter: nextChapter)
            } label: {
                HStack(spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(course.accent.coverGradient)
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 82, height: 82)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(course.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(nextChapter.chapterTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        ProgressView(value: model.completion(for: course, chapter: nextChapter))
                            .tint(course.accent.color)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                        .foregroundStyle(course.accent.color)
                }
                .scholarCard()
            }
            .buttonStyle(.scaling)
        }
    }
}
