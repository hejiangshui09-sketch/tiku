import Foundation
import SwiftUI

struct CourseCatalogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isPickingFiles = false
    @State private var importPreviews: [CourseImportPreview]?
    @State private var coursePendingDeletion: Course?
    @State private var searchText = ""
    @State private var sortOption: CourseSortOption = .recent
    @State private var selectedShelfID = ""
    @State private var shelfEditor: ShelfEditorPayload?
    @State private var shelfPendingDeletion: LibraryShelf?

    private var selectedShelf: LibraryShelf {
        model.libraryShelves.first { $0.id == selectedShelfID } ?? model.defaultShelf
    }

    private var filteredCourses: [Course] {
        var result = model.courses(in: selectedShelf)
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.subject.localizedCaseInsensitiveContains(query)
                    || $0.subtitle.localizedCaseInsensitiveContains(query)
            }
        }
        switch sortOption {
        case .recent:
            return result.sorted {
                (model.lastStudied($0) ?? .distantPast) > (model.lastStudied($1) ?? .distantPast)
            }
        case .title:
            return result.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .progress:
            return result.sorted { model.courseCompletion($0) > model.courseCompletion($1) }
        case .questions:
            return result.sorted { $0.totalQuestions > $1.totalQuestions }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    catalogHero
                    shelfSelector

                    HStack(spacing: 14) {
                        SectionHeading(
                            title: selectedShelf.name,
                            subtitle: "\(model.courses(in: selectedShelf).count) 本书 · \(model.courses.count) 本书已入库"
                        )
                        Menu {
                            Picker("排序", selection: $sortOption) {
                                ForEach(CourseSortOption.allCases) { option in
                                    Label(option.title, systemImage: option.symbol).tag(option)
                                }
                            }
                        } label: {
                            Label(sortOption.title, systemImage: "arrow.up.arrow.down")
                                .font(.subheadline.weight(.semibold))
                        }
                        .menuStyle(.button)
                        .buttonStyle(.bordered)
                    }

                    if model.courses.isEmpty {
                        EmptyState(
                            symbol: "books.vertical",
                            title: "书柜还是空的",
                            detail: "导入一本书的课程 JSON，按书柜和抽屉整理知识与题库",
                            actionTitle: "导入书籍",
                            action: { isPickingFiles = true }
                        )
                        .frame(height: 360)
                    } else if filteredCourses.isEmpty {
                        EmptyState(
                            symbol: searchText.isEmpty ? "books.vertical" : "magnifyingglass",
                            title: searchText.isEmpty ? "这个书柜还是空的" : "没有匹配的书籍",
                            detail: searchText.isEmpty ? "导入书籍，或长按其他书柜中的书籍移动到这里" : "换个关键词试试"
                        )
                            .frame(height: 280)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 18)], spacing: 18) {
                            ForEach(filteredCourses) { course in
                                NavigationLink {
                                    CourseDetailView(course: course)
                                } label: {
                                    CourseSummaryCard(course: course)
                                }
                                .buttonStyle(.scaling)
                                .contextMenu {
                                    accentMenu(for: course)
                                    moveMenu(for: course)
                                    if !course.source.isBundled {
                                        Divider()
                                        Button(role: .destructive) {
                                            coursePendingDeletion = course
                                        } label: {
                                            Label("删除课程", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .animation(ScholarTheme.Motion.snappy, value: filteredCourses.map(\.id))
                    }
                }
                .padding(ScholarTheme.Spacing.pagePadding)
                .frame(maxWidth: 1320, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索课程名称或学科")
            .navigationTitle("我的书柜")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        shelfEditor = ShelfEditorPayload(shelf: nil)
                    } label: {
                        Label("新建书柜", systemImage: "books.vertical.fill")
                    }
                    Button {
                        isPickingFiles = true
                    } label: {
                        Label("导入书籍", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $isPickingFiles) {
                CourseDocumentPicker(
                    onPick: { urls in
                        isPickingFiles = false
                        guard !urls.isEmpty else { return }
                        Task {
                            let previews = await model.previewImports(from: urls)
                            importPreviews = previews
                        }
                    },
                    onCancel: { isPickingFiles = false }
                )
            }
            .sheet(item: Binding(
                get: { importPreviews.map(ImportPreviewPayload.init) },
                set: { if $0 == nil { importPreviews = nil } }
            )) { payload in
                ImportPreviewSheet(previews: payload.previews) {
                    importPreviews = nil
                }
            }
            .sheet(item: $shelfEditor) { payload in
                ShelfEditorSheet(shelf: payload.shelf) { shelfID in
                    selectedShelfID = shelfID
                }
            }
            .alert(
                "删除课程？",
                isPresented: Binding(
                    get: { coursePendingDeletion != nil },
                    set: { if !$0 { coursePendingDeletion = nil } }
                ),
                presenting: coursePendingDeletion
            ) { course in
                Button("删除“\(course.title)”", role: .destructive) {
                    Task { await model.deleteCourse(course) }
                    coursePendingDeletion = nil
                }
                Button("取消", role: .cancel) {
                    coursePendingDeletion = nil
                }
            } message: { _ in
                Text("该课程的进度、复习计划、收藏和笔记也会被删除。")
            }
            .confirmationDialog(
                "删除书柜？",
                isPresented: Binding(
                    get: { shelfPendingDeletion != nil },
                    set: { if !$0 { shelfPendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: shelfPendingDeletion
            ) { shelf in
                Button("删除“\(shelf.name)”", role: .destructive) {
                    model.deleteShelf(shelf)
                    selectedShelfID = model.defaultShelf.id
                    shelfPendingDeletion = nil
                }
                Button("取消", role: .cancel) { shelfPendingDeletion = nil }
            } message: { _ in
                Text("书柜中的课程不会被删除，会移入默认书柜。")
            }
            .onAppear {
                if selectedShelfID.isEmpty {
                    selectedShelfID = model.defaultShelf.id
                }
            }
        }
    }

    private var shelfSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(model.libraryShelves) { shelf in
                    Button {
                        Haptics.selection()
                        selectedShelfID = shelf.id
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: selectedShelfID == shelf.id ? "books.vertical.fill" : "books.vertical")
                                    .font(.title2)
                                Spacer()
                                Text("\(model.courses(in: shelf).count)")
                                    .font(.caption.weight(.bold))
                                    .monospacedDigit()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.18), in: Capsule())
                            }
                            Text(shelf.name)
                                .font(.headline)
                                .lineLimit(1)
                            Text("打开书柜")
                                .font(.caption)
                                .opacity(0.75)
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .frame(width: 210, height: 122, alignment: .leading)
                        .background(
                            selectedShelfID == shelf.id
                                ? AnyShapeStyle(LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(LinearGradient(colors: [.brown.opacity(0.85), .orange.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay(alignment: .bottom) {
                            HStack(spacing: 5) {
                                ForEach(0..<5, id: \.self) { _ in
                                    Capsule().fill(.white.opacity(0.22)).frame(height: 4)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 9)
                        }
                    }
                    .buttonStyle(.scaling)
                    .contextMenu {
                        Button {
                            shelfEditor = ShelfEditorPayload(shelf: shelf)
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        if shelf.id != model.defaultShelf.id {
                            Button(role: .destructive) {
                                shelfPendingDeletion = shelf
                            } label: {
                                Label("删除书柜", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 3)
        }
    }

    private func accentMenu(for course: Course) -> some View {
        Menu {
            ForEach(CourseAccent.allCases, id: \.self) { accent in
                Button {
                    Task { await model.updateCourseAccent(course, accent: accent) }
                } label: {
                    Label(accent.title, systemImage: course.accent == accent ? "checkmark.circle.fill" : "circle.fill")
                }
            }
        } label: {
            Label("课程主题色", systemImage: "paintpalette")
        }
    }

    private func moveMenu(for course: Course) -> some View {
        Menu {
            ForEach(model.libraryShelves) { shelf in
                Button {
                    model.moveCourse(course, to: shelf)
                } label: {
                    Label(shelf.name, systemImage: model.shelfID(for: course) == shelf.id ? "checkmark" : "books.vertical")
                }
            }
        } label: {
            Label("移动到书柜", systemImage: "tray.and.arrow.down")
        }
    }

    private var catalogHero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("书柜资料库")
                    .font(ScholarFont.display(0.95))
                Text("每个书柜收纳一类书籍，每本书的章节都按抽屉拆分为单元知识与题库。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    isPickingFiles = true
                } label: {
                    Label("导入书籍 JSON", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
            Spacer()
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
        }
        .scholarCard()
    }
}

enum CourseSortOption: String, CaseIterable, Identifiable {
    case recent, title, progress, questions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "最近学习"
        case .title: "名称"
        case .progress: "完成度"
        case .questions: "题量"
        }
    }

    var symbol: String {
        switch self {
        case .recent: "clock"
        case .title: "textformat"
        case .progress: "chart.pie"
        case .questions: "checkmark.circle"
        }
    }
}

private struct ImportPreviewPayload: Identifiable {
    let previews: [CourseImportPreview]
    var id: String { previews.map(\.id).joined() }
}

private struct ShelfEditorPayload: Identifiable {
    let shelf: LibraryShelf?
    var id: String { shelf?.id ?? "new-library-shelf" }
}

private struct ShelfEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let shelf: LibraryShelf?
    let onSaved: (String) -> Void
    @State private var name: String

    init(shelf: LibraryShelf?, onSaved: @escaping (String) -> Void) {
        self.shelf = shelf
        self.onSaved = onSaved
        _name = State(initialValue: shelf?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例如：公务员行测", text: $name)
                } header: {
                    Text("书柜名称")
                } footer: {
                    Text("书柜用于收纳同一本书或同一类学习资料，之后可以随时重命名。")
                }
            }
            .navigationTitle(shelf == nil ? "新建书柜" : "重命名书柜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let shelf {
                            model.renameShelf(shelf, to: name)
                            onSaved(shelf.id)
                        } else if let created = model.createShelf(named: name) {
                            onSaved(created.id)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 课程卡片

struct CourseSummaryCard: View {
    @EnvironmentObject private var model: AppModel
    let course: Course

    private var completion: Double { model.courseCompletion(course) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面区
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 0)
                    .fill(course.accent.coverGradient)
                Image(systemName: course.accent.coverSymbol)
                    .font(.system(size: 88, weight: .light))
                    .foregroundStyle(.white.opacity(0.18))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 18)
                    .offset(y: 12)
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.subject)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.18), in: Capsule())
                    Text(course.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
            }
            .frame(height: 124)
            .clipped()

            // 信息区
            VStack(alignment: .leading, spacing: 13) {
                if !course.subtitle.isEmpty {
                    Text(course.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    InfoChip(text: "\(course.payload.totalChapters) 章", symbol: "list.number", color: course.accent.color)
                    InfoChip(text: "\(course.totalQuestions) 题", symbol: "checkmark.circle", color: course.accent.color)
                    InfoChip(text: course.source.title, symbol: "tray", color: .secondary)
                }

                HStack(spacing: 12) {
                    ProgressView(value: completion)
                        .tint(course.accent.color)
                    Text(completion, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                if let lastStudied = model.lastStudied(course) {
                    Text("上次学习 \(lastStudied.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
        }
        .background(ScholarTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous)
                .stroke(.primary.opacity(0.055), lineWidth: 1)
        }
        .shadow(color: course.accent.color.opacity(0.1), radius: 16, y: 8)
    }
}
