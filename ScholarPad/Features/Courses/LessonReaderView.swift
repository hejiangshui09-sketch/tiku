import SwiftUI

struct LessonReaderView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    let course: Course
    let chapter: Chapter

    @State private var selectedModule: Int
    @State private var fontScale = 1.0
    @State private var focusMode = false
    @State private var activeStartedAt: Date?

    init(course: Course, chapter: Chapter, initialModule: Int = 0) {
        self.course = course
        self.chapter = chapter
        _selectedModule = State(
            initialValue: chapter.knowledgePoints.indices.contains(initialModule) ? initialModule : 0
        )
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                if !focusMode && proxy.size.width > 850 {
                    outline
                        .frame(width: 280)
                        .background(.thinMaterial)
                    Divider()
                }
                lessonContent
            }
        }
        .background(ScholarTheme.page)
        .navigationTitle(chapter.chapterTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("较小字号") { fontScale = 0.9 }
                    Button("标准字号") { fontScale = 1.0 }
                    Button("较大字号") { fontScale = 1.18 }
                } label: {
                    Label("字号", systemImage: "textformat.size")
                }
                Button {
                    withAnimation(.snappy) { focusMode.toggle() }
                } label: {
                    Label(focusMode ? "退出专注" : "专注阅读", systemImage: focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
            }
        }
        .onAppear {
            if scenePhase == .active {
                activeStartedAt = Date()
            }
        }
        .onDisappear {
            recordActiveStudyTime()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                activeStartedAt = Date()
            } else {
                recordActiveStudyTime()
            }
        }
    }

    private var outline: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("本章目录")
                    .font(.headline)
                    .padding(.bottom, 8)

                ForEach(Array(chapter.knowledgePoints.enumerated()), id: \.offset) { index, point in
                    Button {
                        withAnimation(.snappy) { selectedModule = index }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: model.progress(for: course, chapter: chapter).completedModuleIndexes.contains(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.progress(for: course, chapter: chapter).completedModuleIndexes.contains(index) ? .green : .secondary)
                            Text(point.title)
                                .font(.subheadline.weight(index == selectedModule ? .semibold : .regular))
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(10)
                        .background(index == selectedModule ? course.accent.color.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Divider().padding(.vertical, 8)

                if chapter.questions.all.isEmpty {
                    Label("本章暂无练习", systemImage: "checkmark.seal")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .foregroundStyle(.secondary)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    NavigationLink {
                        QuizSessionView(course: course, chapter: chapter, questions: chapter.questions.all)
                    } label: {
                        Label("开始章节练习", systemImage: "checkmark.seal")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(course.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }

    private var lessonContent: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    chapterIntro

                    ForEach(Array(chapter.knowledgePoints.enumerated()), id: \.offset) { index, point in
                        KnowledgeModuleCard(
                            course: course,
                            chapter: chapter,
                            point: point,
                            index: index,
                            fontScale: fontScale
                        )
                        .id(index)
                    }

                    practiceCallout
                }
                .padding(28)
                .frame(maxWidth: focusMode ? 820 : 980, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: selectedModule) { _, newValue in
                withAnimation(.smooth) { reader.scrollTo(newValue, anchor: .top) }
            }
            .onAppear {
                reader.scrollTo(selectedModule, anchor: .top)
            }
        }
    }

    private var chapterIntro: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(course.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(course.accent.color)
            Text(chapter.chapterTitle)
                .font(.system(size: 34 * fontScale, weight: .bold, design: .rounded))
            Text("本章包含 \(chapter.knowledgePoints.count) 个知识模块与 \(chapter.stats.totalQuestions) 道练习。先理解，再通过练习完成主动回忆。")
                .font(.system(size: 17 * fontScale))
                .foregroundStyle(.secondary)
                .lineSpacing(5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private var practiceCallout: some View {
        HStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(course.accent.color)
            VStack(alignment: .leading, spacing: 5) {
                Text("完成本章主动练习")
                    .font(.headline)
                Text("通过题目检验理解，并将薄弱项加入复习。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if chapter.questions.all.isEmpty {
                Text("暂无练习")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink {
                    QuizSessionView(course: course, chapter: chapter, questions: chapter.questions.all)
                } label: {
                    Text("开始练习")
                }
                .buttonStyle(.borderedProminent)
                .tint(course.accent.color)
            }
        }
        .scholarCard()
    }

    private func recordActiveStudyTime() {
        guard let activeStartedAt else { return }
        self.activeStartedAt = nil
        model.recordStudy(
            course: course,
            chapter: chapter,
            seconds: Date().timeIntervalSince(activeStartedAt)
        )
    }
}

private struct KnowledgeModuleCard: View {
    @EnvironmentObject private var model: AppModel
    let course: Course
    let chapter: Chapter
    let point: KnowledgePoint
    let index: Int
    let fontScale: Double
    @State private var showingNote = false

    private var isCompleted: Bool {
        model.progress(for: course, chapter: chapter).completedModuleIndexes.contains(index)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Text("\(index + 1)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(course.accent.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(point.title)
                        .font(.system(size: 22 * fontScale, weight: .bold))
                    if !point.description.isEmpty {
                        Text(.init(point.description))
                            .font(.system(size: 17 * fontScale))
                            .foregroundStyle(.secondary)
                            .lineSpacing(5)
                    }
                }
                Spacer()
            }

            if !point.subPoints.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(point.subPoints.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(course.accent.color)
                                .padding(.top, 8)
                            Text(.init(item))
                                .font(.system(size: 16 * fontScale))
                                .lineSpacing(5)
                        }
                    }
                }
                .padding(16)
                .background(course.accent.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            if let resources = point.resources, !resources.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("拓展资源")
                        .font(.subheadline.weight(.semibold))
                    ForEach(resources) { resource in
                        HStack(spacing: 10) {
                            NavigationLink {
                                ResourceViewerView(
                                    resource: resource,
                                    localURL: model.cachedURL(for: resource)
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: resource.kind.symbol)
                                        .foregroundStyle(course.accent.color)
                                        .frame(width: 36, height: 36)
                                        .background(course.accent.color.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(resource.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(model.cachedURL(for: resource) == nil ? (resource.detail ?? resource.kind.title) : "已下载 · \(resource.detail ?? resource.kind.title)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task {
                                    if model.cachedURL(for: resource) == nil {
                                        await model.downloadResource(resource)
                                    } else {
                                        await model.removeDownloadedResource(resource)
                                    }
                                }
                            } label: {
                                Image(systemName: model.cachedURL(for: resource) == nil ? "arrow.down.circle" : "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(model.cachedURL(for: resource) == nil ? course.accent.color : .green)
                                    .frame(width: 42, height: 42)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(ScholarTheme.elevated, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
            }

            HStack {
                Button {
                    model.markModule(course: course, chapter: chapter, index: index, completed: !isCompleted)
                } label: {
                    Label(isCompleted ? "已掌握" : "标记为已掌握", systemImage: isCompleted ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.bordered)
                .tint(isCompleted ? .green : course.accent.color)

                Button {
                    showingNote = true
                } label: {
                    Label(
                        model.note(course: course, chapter: chapter, moduleIndex: index) == nil ? "添加笔记" : "编辑笔记",
                        systemImage: "note.text"
                    )
                }
                .buttonStyle(.bordered)
            }
        }
        .scholarCard(padding: 24)
        .sheet(isPresented: $showingNote) {
            StudyNoteEditor(course: course, chapter: chapter, point: point, moduleIndex: index)
        }
    }
}

private struct StudyNoteEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let course: Course
    let chapter: Chapter
    let point: KnowledgePoint
    let moduleIndex: Int
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(point.title)
                        .font(.title2.weight(.bold))
                    Text(chapter.chapterTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $text)
                    .font(.body)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(ScholarTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("记录你的理解、疑问、例子或复习提示…")
                                .foregroundStyle(.tertiary)
                                .padding(18)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(24)
            .navigationTitle("学习笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        model.saveNote(
                            course: course,
                            chapter: chapter,
                            moduleIndex: moduleIndex,
                            text: text
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            text = model.note(course: course, chapter: chapter, moduleIndex: moduleIndex)?.text ?? ""
        }
        .presentationDetents([.medium, .large])
    }
}
