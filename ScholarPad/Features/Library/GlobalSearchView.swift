import SwiftUI

struct GlobalSearchView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    private var results: [SearchResult] {
        model.search(query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchPrompt
                } else if results.isEmpty {
                    EmptyState(symbol: "magnifyingglass", title: "没有找到相关内容", detail: "试试章节名、知识点关键词或题干中的词语")
                } else {
                    List(results) { result in
                        if let course = model.course(id: result.courseID),
                           let chapter = model.chapter(courseID: result.courseID, chapterID: result.chapterID) {
                            NavigationLink {
                                LessonReaderView(
                                    course: course,
                                    chapter: chapter,
                                    initialModule: result.moduleIndex ?? 0
                                )
                            } label: {
                                SearchResultRow(result: result)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("全局搜索")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索课程中的一切")
        }
    }

    private var searchPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 72))
                .foregroundStyle(.indigo)
                .symbolRenderingMode(.hierarchical)
            Text("快速定位知识")
                .font(.largeTitle.weight(.bold))
            Text("同时搜索所有课程的章节、知识点和题目。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(.indigo)
                .frame(width: 42, height: 42)
                .background(.indigo.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(RichContentFormatter.previewText(result.detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }

    private var symbol: String {
        switch result.kind {
        case .chapter: "book.closed"
        case .knowledgePoint: "lightbulb"
        case .question: "checkmark.circle"
        case .note: "note.text"
        }
    }
}
