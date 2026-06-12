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
                    title: "课程章节",
                    subtitle: "\(course.payload.totalChapters) 个章节 · \(course.totalKnowledgeModules) 个知识模块 · \(course.totalQuestions) 道练习"
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
                NavigationLink {
                    LessonReaderView(course: course, chapter: chapter)
                } label: {
                    ChapterRow(
                        course: course,
                        chapter: chapter,
                        index: index,
                        isResume: chapter.id == resumeChapter?.id && model.courseCompletion(course) > 0
                    )
                }
                .buttonStyle(.scaling)
            }
        }
    }
}

// MARK: - 章节行

private struct ChapterRow: View {
    @EnvironmentObject private var model: AppModel
    let course: Course
    let chapter: Chapter
    let index: Int
    let isResume: Bool

    private var completion: Double { model.completion(for: course, chapter: chapter) }
    private var isDone: Bool { completion >= 1 }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isDone ? Color.green.opacity(0.13) : course.accent.color.opacity(0.12))
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
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(chapter.chapterTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if isResume {
                        InfoChip(text: "上次学到这里", symbol: "play.fill", color: course.accent.color)
                    }
                }
                HStack(spacing: 12) {
                    Label("\(chapter.knowledgePoints.count) 个知识点", systemImage: "lightbulb")
                    if chapter.stats.totalQuestions > 0 {
                        Label("\(chapter.stats.totalQuestions) 道练习", systemImage: "checkmark.circle")
                    }
                    if chapter.stats.shortAnswer > 0 {
                        Label("\(chapter.stats.shortAnswer) 道简答", systemImage: "text.alignleft")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ProgressView(value: completion)
                    .tint(isDone ? .green : course.accent.color)
                    .frame(maxWidth: 320)
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(completion, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isDone ? .green : course.accent.color)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
        }
        .scholarCard(padding: 16)
    }
}
