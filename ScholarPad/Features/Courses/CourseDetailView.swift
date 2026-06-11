import SwiftUI

struct CourseDetailView: View {
    @EnvironmentObject private var model: AppModel
    let course: Course

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                courseHeader
                SectionHeading(
                    title: "课程章节",
                    subtitle: "\(course.payload.totalChapters) 个章节 · \(course.totalKnowledgeModules) 个知识模块"
                )
                chapterList
            }
            .padding(28)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .background(ScholarTheme.page)
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var courseHeader: some View {
        HStack(spacing: 26) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white)
                .frame(width: 112, height: 112)
                .background(course.accent.gradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: course.accent.color.opacity(0.22), radius: 20, y: 10)

            VStack(alignment: .leading, spacing: 9) {
                Text(course.subject)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(course.accent.color)
                Text(course.title)
                    .font(.largeTitle.weight(.bold))
                Text(course.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                HStack(spacing: 18) {
                    Label("\(course.payload.totalChapters) 章", systemImage: "list.number")
                    Label("\(course.totalQuestions) 题", systemImage: "checkmark.circle")
                    Label("支持离线", systemImage: "arrow.down.circle")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            ProgressRing(value: model.courseCompletion(course), size: 82, lineWidth: 9, color: course.accent.color)
        }
        .scholarCard(padding: 26)
    }

    private var chapterList: some View {
        LazyVStack(spacing: 14) {
            ForEach(Array(course.payload.chapters.enumerated()), id: \.element.id) { index, chapter in
                NavigationLink {
                    LessonReaderView(course: course, chapter: chapter)
                } label: {
                    ChapterRow(course: course, chapter: chapter, index: index)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ChapterRow: View {
    @EnvironmentObject private var model: AppModel
    let course: Course
    let chapter: Chapter
    let index: Int

    var body: some View {
        HStack(spacing: 18) {
            Text(String(format: "%02d", index + 1))
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(course.accent.color)
                .frame(width: 48, height: 48)
                .background(course.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(chapter.chapterTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 14) {
                    Label("\(chapter.knowledgePoints.count) 个知识点", systemImage: "lightbulb")
                    Label("\(chapter.stats.totalQuestions) 道练习", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            ProgressRing(value: model.completion(for: course, chapter: chapter), size: 48, lineWidth: 5, color: course.accent.color)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .scholarCard(padding: 16)
    }
}

