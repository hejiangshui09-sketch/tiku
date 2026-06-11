import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.allNotes().isEmpty {
                    EmptyState(
                        symbol: "note.text",
                        title: "还没有学习笔记",
                        detail: "在章节阅读中为知识点记录理解、疑问和例子"
                    )
                } else {
                    List(model.allNotes()) { context in
                        NavigationLink {
                            LessonReaderView(
                                course: context.course,
                                chapter: context.chapter,
                                initialModule: context.note.moduleIndex
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(context.knowledgePoint.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(context.note.updatedAt, format: .dateTime.month().day())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(context.note.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                Text("\(context.course.title) · \(context.chapter.chapterTitle)")
                                    .font(.caption)
                                    .foregroundStyle(context.course.accent.color)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("学习笔记")
        }
    }
}
