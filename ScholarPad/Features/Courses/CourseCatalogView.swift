import Foundation
import SwiftUI

struct CourseCatalogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isPickingFiles = false
    @State private var importPreviews: [CourseImportPreview]?
    @State private var coursePendingDeletion: Course?
    @State private var searchText = ""
    @State private var sortOption: CourseSortOption = .recent

    private var filteredCourses: [Course] {
        var result = model.courses
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

                    HStack(spacing: 14) {
                        SectionHeading(
                            title: "全部课程",
                            subtitle: "\(model.courses.count) 门课程已就绪，支持离线学习"
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
                            title: "还没有课程",
                            detail: "导入解析器生成的课程 JSON 或单章 JSON 开始学习",
                            actionTitle: "导入课程",
                            action: { isPickingFiles = true }
                        )
                        .frame(height: 360)
                    } else if filteredCourses.isEmpty {
                        EmptyState(symbol: "magnifyingglass", title: "没有匹配的课程", detail: "换个关键词试试")
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
            .navigationTitle("我的课程")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPickingFiles = true
                    } label: {
                        Label("导入课程", systemImage: "square.and.arrow.down")
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

    private var catalogHero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("课程资料库")
                    .font(ScholarFont.display(0.95))
                Text("统一管理章节、知识点和题目。新的解析结果可随时导入，导入前可预览确认。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    isPickingFiles = true
                } label: {
                    Label("导入课程 JSON", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
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
