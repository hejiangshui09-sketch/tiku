import SwiftUI

struct SavedItemsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.savedQuestions().isEmpty {
                    EmptyState(symbol: "bookmark", title: "还没有收藏", detail: "练习时点击书签，可把重点题目集中到这里")
                } else {
                    List {
                        ForEach(model.savedQuestions()) { item in
                            NavigationLink {
                                QuizSessionView(course: item.course, chapter: item.chapter, questions: [item.question])
                            } label: {
                                SavedQuestionRow(course: item.course, chapter: item.chapter, question: item.question)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("我的收藏")
        }
    }
}

private struct SavedQuestionRow: View {
    let course: Course
    let chapter: Chapter
    let question: Question

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: question.type.symbol)
                .font(.headline)
                .foregroundStyle(course.accent.color)
                .frame(width: 42, height: 42)
                .background(course.accent.color.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                RichInlineText(question.question, font: .headline, color: .primary)
                    .lineLimit(2)
                Text("\(chapter.chapterTitle) · \(question.type.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
