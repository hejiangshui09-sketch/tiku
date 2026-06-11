import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    private var continueCourse: Course? {
        model.courses.max { model.courseCompletion($0) < model.courseCompletion($1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    welcomeHero
                    metrics

                    if !model.dueReviewQuestions().isEmpty {
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
                        .buttonStyle(.plain)
                    }

                    if let course = continueCourse {
                        SectionHeading(title: "继续学习", subtitle: "沿着上次的进度继续，不必重新寻找")
                        ContinueCourseCard(course: course)
                    }

                    SectionHeading(title: "课程总览", subtitle: "知识、练习和复习统一组织")
                    courseGrid
                }
                .padding(28)
                .frame(maxWidth: 1320, alignment: .leading)
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

    private var welcomeHero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 13) {
                Text(greeting)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                Text("今天，继续把知识\n变成真正的掌握。")
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
                colors: [Color.indigo, Color.blue.opacity(0.82), Color.cyan.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: .indigo.opacity(0.18), radius: 24, y: 12)
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
            MetricTile(title: "累计学习", value: formattedStudyTime, symbol: "clock.fill", color: .indigo)
            MetricTile(title: "已练题目", value: "\(model.attemptedQuestions)", symbol: "checkmark.seal.fill", color: .cyan)
            MetricTile(title: "答题正确率", value: accuracyText, symbol: "scope", color: .green)
            MetricTile(title: "连续学习", value: "\(model.streakDays) 天", symbol: "flame.fill", color: .orange)
        }
    }

    private var courseGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 18)], spacing: 18) {
            ForEach(model.courses) { course in
                NavigationLink {
                    CourseDetailView(course: course)
                } label: {
                    CourseSummaryCard(course: course)
                }
                .buttonStyle(.plain)
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
        return Double(model.correctQuestions) / Double(model.attemptedQuestions)
            .formatted(.percent.precision(.fractionLength(0)))
    }
}

private struct ContinueCourseCard: View {
    @EnvironmentObject private var model: AppModel
    let course: Course

    private var nextChapter: Chapter? {
        course.payload.chapters.first { model.completion(for: course, chapter: $0) < 1 }
            ?? course.payload.chapters.first
    }

    var body: some View {
        if let nextChapter {
            NavigationLink {
                LessonReaderView(course: course, chapter: nextChapter)
            } label: {
                HStack(spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(course.accent.gradient)
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
            .buttonStyle(.plain)
        }
    }
}

struct CourseSummaryCard: View {
    @EnvironmentObject private var model: AppModel
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "books.vertical.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(course.accent.gradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                Spacer()
                ProgressRing(value: model.courseCompletion(course), size: 54, color: course.accent.color)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(course.subject)
                        .foregroundStyle(course.accent.color)
                    Spacer()
                    Text(course.source.title)
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.semibold))
                Text(course.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(course.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 16) {
                Label("\(course.payload.totalChapters) 章", systemImage: "list.number")
                Label("\(course.totalQuestions) 题", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 205, alignment: .leading)
        .scholarCard()
    }
}
