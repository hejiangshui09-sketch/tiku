import SwiftUI

struct CourseDetailView: View {
    @EnvironmentObject private var model: AppModel
    let course: Course

    private var resumeChapter: Chapter? { model.resumeChapter(for: course) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                courseHeader

                SectionHeading(
                    title: "章节抽屉",
                    subtitle: "\(course.payload.totalChapters) 个抽屉 · 每个抽屉分别收纳单元知识与题库"
                )
                chapterList
            }
            .padding(ScholarTheme.Spacing.pagePadding)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(ScholarTheme.page)
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 封面头图

    private var courseHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: ScholarTheme.heroRadius, style: .continuous)
                .fill(course.accent.coverGradient)

            Image(systemName: course.accent.coverSymbol)
                .font(.system(size: 170, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.14))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 26)
                .padding(.top, -20)
                .clipped()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    InfoChip(text: course.subject, symbol: "graduationcap", color: .white)
                    InfoChip(text: course.source.title, symbol: "tray", color: .white)
                }

                Text(course.title)
                    .font(ScholarFont.display(1.0))
                    .foregroundStyle(.white)

                if !course.subtitle.isEmpty {
                    Text(course.subtitle)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }

                HStack(spacing: 16) {
                    if let resumeChapter, !course.payload.chapters.isEmpty {
                        NavigationLink {
                            LessonReaderView(course: course, chapter: resumeChapter)
                        } label: {
                            Label(
                                model.courseCompletion(course) > 0 ? "继续学习" : "开始学习",
                                systemImage: "play.fill"
                            )
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(.white, in: Capsule())
                            .foregroundStyle(course.accent.color)
                        }
                        .buttonStyle(.scaling)
                    }

                    HStack(spacing: 10) {
                        ProgressRing(
                            value: model.courseCompletion(course),
                            size: 44,
                            lineWidth: 5,
                            color: .white,
                            showsLabel: false
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.courseCompletion(course), format: .percent.precision(.fractionLength(0)))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text("总进度")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(28)
        }
        .frame(minHeight: 250)
        .shadow(color: course.accent.color.opacity(0.28), radius: 26, y: 14)
    }

    // MARK: - 章节列表

    private var chapterList: some View {
        LazyVStack(spacing: 14) {
            ForEach(Array(course.payload.chapters.enumerated()), id: \.element.id) { index, chapter in
                ChapterDrawerRow(
                    course: course,
                    chapter: chapter,
                    index: index,
                    isResume: chapter.id == resumeChapter?.id && model.courseCompletion(course) > 0
                )
            }
        }
    }
}

// MARK: - 章节抽屉

private struct ChapterDrawerRow: View {
    @EnvironmentObject private var model: AppModel
    let course: Course
    let chapter: Chapter
    let index: Int
    let isResume: Bool

    private var completion: Double { model.completion(for: course, chapter: chapter) }
    private var isDone: Bool { completion >= 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isDone ? Color.green.opacity(0.14) : course.accent.color.opacity(0.13))
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.green)
                    } else {
                        Text(String(format: "%02d", index + 1))
                            .font(.headline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(course.accent.color)
                    }
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(chapter.chapterTitle)
                            .font(.headline)
                            .lineLimit(2)
                        if isResume {
                            InfoChip(text: "上次学到这里", symbol: "play.fill", color: course.accent.color)
                        }
                    }
                    Text("\(chapter.knowledgePoints.count) 个知识模块 · \(chapter.stats.totalQuestions) 道题")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(completion, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isDone ? .green : course.accent.color)
            }
            .padding(16)

            Divider().opacity(0.55)

            HStack(spacing: 12) {
                if !chapter.knowledgePoints.isEmpty {
                    NavigationLink {
                        LessonReaderView(course: course, chapter: chapter)
                    } label: {
                        drawerHandle(
                            title: "单元知识",
                            detail: "\(chapter.knowledgePoints.count) 个模块",
                            symbol: "lightbulb.fill",
                            color: course.accent.color
                        )
                    }
                    .buttonStyle(.scaling)
                }

                if !chapter.questions.all.isEmpty {
                    NavigationLink {
                        QuizSessionView(course: course, chapter: chapter, questions: chapter.questions.all)
                    } label: {
                        drawerHandle(
                            title: "题库",
                            detail: "\(chapter.stats.totalQuestions) 道练习",
                            symbol: "checkmark.seal.fill",
                            color: .orange
                        )
                    }
                    .buttonStyle(.scaling)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.025))
        }
        .background(ScholarTheme.card, in: RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.045), radius: 12, y: 6)
    }

    private func drawerHandle(title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Capsule()
                .fill(color.opacity(0.45))
                .frame(width: 34, height: 5)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(ScholarTheme.elevated, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}
