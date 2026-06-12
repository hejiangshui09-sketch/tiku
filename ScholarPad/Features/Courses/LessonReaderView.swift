import SwiftUI

struct LessonReaderView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var prefs: AppPreferences
    @Environment(\.scenePhase) private var scenePhase
    let course: Course
    let chapter: Chapter

    @State private var selectedModule: Int
    @State private var focusMode = false
    @State private var showingReadingOptions = false
    @State private var scrollProgress: Double = 0
    @State private var activeStartedAt: Date?

    init(course: Course, chapter: Chapter, initialModule: Int = 0) {
        self.course = course
        self.chapter = chapter
        _selectedModule = State(
            initialValue: chapter.knowledgePoints.indices.contains(initialModule) ? initialModule : 0
        )
    }

    private var theme: ReadingTheme { prefs.readingTheme }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                if !focusMode && proxy.size.width > 850 {
                    ReaderOutline(
                        course: course,
                        chapter: chapter,
                        selectedModule: $selectedModule,
                        theme: theme
                    )
                    .frame(width: 280)
                    .background(theme == .standard ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(theme.cardBackground.opacity(0.6)))
                    Divider()
                }
                lessonContent
            }
        }
        .background(theme.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            // 顶部阅读进度条
            GeometryReader { proxy in
                Rectangle()
                    .fill(course.accent.color)
                    .frame(width: proxy.size.width * scrollProgress)
                    .animation(.linear(duration: 0.1), value: scrollProgress)
            }
            .frame(height: 3)
            .background(course.accent.color.opacity(0.1))
        }
        .navigationTitle(chapter.chapterTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme == .night ? .visible : .automatic, for: .navigationBar)
        .preferredColorScheme(theme.forcedColorScheme ?? prefs.appearance.colorScheme)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingReadingOptions = true
                } label: {
                    Label("阅读设置", systemImage: "textformat.size")
                }
                .popover(isPresented: $showingReadingOptions, arrowEdge: .top) {
                    ReadingOptionsPanel(accent: course.accent.color)
                        .presentationCompactAdaptation(.popover)
                }

                Button {
                    Haptics.light()
                    withAnimation(ScholarTheme.Motion.snappy) { focusMode.toggle() }
                } label: {
                    Label(
                        focusMode ? "退出专注" : "专注阅读",
                        systemImage: focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                    )
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

    // MARK: - 正文

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
                            theme: theme
                        )
                        .id(index)
                    }

                    moduleNavigator(reader: reader)
                    practiceCallout
                }
                .padding(ScholarTheme.Spacing.pagePadding)
                .frame(maxWidth: focusMode ? 760 : 940, alignment: .leading)
                .frame(maxWidth: .infinity)
                .background {
                    GeometryReader { contentProxy in
                        Color.clear.preference(
                            key: ReaderScrollKey.self,
                            value: contentProxy.frame(in: .named("readerScroll"))
                        )
                    }
                }
            }
            .coordinateSpace(name: "readerScroll")
            .onPreferenceChange(ReaderScrollKey.self) { frame in
                let total = max(frame.height - 700, 1)
                scrollProgress = min(1, max(0, -frame.minY / total))
            }
            .onChange(of: selectedModule) { _, newValue in
                withAnimation(ScholarTheme.Motion.smooth) { reader.scrollTo(newValue, anchor: .top) }
            }
            .onAppear {
                if selectedModule > 0 {
                    reader.scrollTo(selectedModule, anchor: .top)
                }
            }
        }
    }

    private var chapterIntro: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(course.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(course.accent.color)
            Text(chapter.chapterTitle)
                .font(.system(size: 34 * prefs.readingFontScale, weight: .bold, design: prefs.readingFontDesign.design))
                .foregroundStyle(theme.textColor)
            Text("本章包含 \(chapter.knowledgePoints.count) 个知识模块与 \(chapter.stats.totalQuestions) 道练习。先理解，再通过练习完成主动回忆。")
                .font(.system(size: 17 * prefs.readingFontScale, design: prefs.readingFontDesign.design))
                .foregroundStyle(theme.secondaryTextColor)
                .lineSpacing(prefs.readingLineSpacing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    // MARK: - 上一节 / 下一节

    private func moduleNavigator(reader: ScrollViewProxy) -> some View {
        HStack(spacing: 14) {
            Button {
                guard selectedModule > 0 else { return }
                Haptics.light()
                selectedModule -= 1
            } label: {
                Label("上一节", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(course.accent.color)
            .disabled(selectedModule <= 0)

            Text("\(selectedModule + 1) / \(chapter.knowledgePoints.count)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(theme.secondaryTextColor)
                .frame(minWidth: 60)

            Button {
                guard selectedModule < chapter.knowledgePoints.count - 1 else { return }
                Haptics.light()
                selectedModule += 1
            } label: {
                Label("下一节", systemImage: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(course.accent.color)
            .disabled(selectedModule >= chapter.knowledgePoints.count - 1)
        }
        .padding(.top, 4)
    }

    private var practiceCallout: some View {
        HStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(course.accent.color)
            VStack(alignment: .leading, spacing: 5) {
                Text("完成本章主动练习")
                    .font(.headline)
                    .foregroundStyle(theme.textColor)
                Text("通过题目检验理解，并将薄弱项加入复习。")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryTextColor)
            }
            Spacer()
            if chapter.questions.all.isEmpty {
                Text("暂无练习")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.secondaryTextColor)
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
        .padding(20)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous)
                .stroke(.primary.opacity(0.055), lineWidth: 1)
        }
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

private struct ReaderScrollKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - 目录侧栏

private struct ReaderOutline: View {
    @EnvironmentObject private var model: AppModel
    let course: Course
    let chapter: Chapter
    @Binding var selectedModule: Int
    let theme: ReadingTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("本章目录")
                        .font(.headline)
                        .foregroundStyle(theme.textColor)
                    Spacer()
                    Text("\(completedCount)/\(chapter.knowledgePoints.count)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.secondaryTextColor)
                }
                .padding(.bottom, 8)

                ForEach(Array(chapter.knowledgePoints.enumerated()), id: \.offset) { index, point in
                    Button {
                        Haptics.selection()
                        withAnimation(ScholarTheme.Motion.snappy) { selectedModule = index }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isCompleted(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isCompleted(index) ? .green : theme.secondaryTextColor)
                                .contentTransition(.symbolEffect(.replace))
                            Text(point.title)
                                .font(.subheadline.weight(index == selectedModule ? .semibold : .regular))
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(theme.textColor)
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            index == selectedModule ? course.accent.color.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Divider().padding(.vertical, 8)

                if chapter.questions.all.isEmpty {
                    Label("本章暂无练习", systemImage: "checkmark.seal")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .foregroundStyle(theme.secondaryTextColor)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    NavigationLink {
                        QuizSessionView(course: course, chapter: chapter, questions: chapter.questions.all)
                    } label: {
                        Label("开始章节练习", systemImage: "checkmark.seal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(course.accent.color)
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

    private var completedCount: Int {
        model.progress(for: course, chapter: chapter).completedModuleIndexes.count
    }

    private func isCompleted(_ index: Int) -> Bool {
        model.progress(for: course, chapter: chapter).completedModuleIndexes.contains(index)
    }
}

// MARK: - 阅读设置面板

struct ReadingOptionsPanel: View {
    @EnvironmentObject private var prefs: AppPreferences
    var accent: Color = .indigo

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 阅读主题
            VStack(alignment: .leading, spacing: 10) {
                Text("阅读主题")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(ReadingTheme.allCases) { theme in
                        Button {
                            Haptics.selection()
                            prefs.readingTheme = theme
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(theme.background)
                                    .frame(width: 52, height: 40)
                                    .overlay {
                                        Text("文")
                                            .font(.system(size: 15, weight: .medium, design: .serif))
                                            .foregroundStyle(theme.textColor)
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                prefs.readingTheme == theme ? accent : Color.primary.opacity(0.12),
                                                lineWidth: prefs.readingTheme == theme ? 2 : 1
                                            )
                                    }
                                Text(theme.title)
                                    .font(.caption2.weight(prefs.readingTheme == theme ? .bold : .regular))
                                    .foregroundStyle(prefs.readingTheme == theme ? accent : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 字体
            VStack(alignment: .leading, spacing: 10) {
                Text("正文字体")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Picker("字体", selection: $prefs.readingFontDesign) {
                    ForEach(ReadingFontDesign.allCases) { design in
                        Text(design.title).tag(design)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 字号
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("字号")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(prefs.readingFontScale, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                }
                HStack(spacing: 12) {
                    Text("A").font(.system(size: 13))
                    Slider(value: $prefs.readingFontScale, in: 0.85...1.5, step: 0.05)
                        .tint(accent)
                    Text("A").font(.system(size: 21, weight: .semibold))
                }
            }

            // 行距
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("行距")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f", prefs.readingLineSpacing))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                }
                HStack(spacing: 12) {
                    Image(systemName: "text.justify").font(.caption)
                    Slider(value: $prefs.readingLineSpacing, in: 2...14, step: 1)
                        .tint(accent)
                    Image(systemName: "text.justify.leading").font(.body)
                }
            }

            Button {
                Haptics.light()
                prefs.readingFontScale = 1.0
                prefs.readingLineSpacing = 6
                prefs.readingFontDesign = .system
                prefs.readingTheme = .standard
            } label: {
                Text("恢复默认")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(width: 320)
    }
}

// MARK: - 知识模块卡片

private struct KnowledgeModuleCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var prefs: AppPreferences
    let course: Course
    let chapter: Chapter
    let point: KnowledgePoint
    let index: Int
    let theme: ReadingTheme
    @State private var showingNote = false

    private var fontScale: Double { prefs.readingFontScale }
    private var lineSpacing: Double { prefs.readingLineSpacing }
    private var design: Font.Design { prefs.readingFontDesign.design }

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
                VStack(alignment: .leading, spacing: 6) {
                    Text(point.title)
                        .font(.system(size: 22 * fontScale, weight: .bold, design: design))
                        .foregroundStyle(theme.textColor)
                    if !point.description.isEmpty {
                        RichContentView(
                            content: point.description,
                            bodyFont: .system(size: 17 * fontScale, design: design),
                            headingFont: .system(size: 19 * fontScale, weight: .bold, design: design),
                            textColor: theme.secondaryTextColor,
                            headingColor: theme.textColor,
                            accentColor: course.accent.color,
                            lineSpacing: lineSpacing
                        )
                    }
                }
                Spacer()
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            if !point.subPoints.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(point.subPoints.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(course.accent.color)
                                .padding(.top, 8)
                            RichInlineText(
                                item,
                                font: .system(size: 16 * fontScale, design: design),
                                color: theme.textColor,
                                lineSpacing: lineSpacing
                            )
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
                        .foregroundStyle(theme.textColor)
                    ForEach(resources) { resource in
                        ResourceRow(course: course, resource: resource, theme: theme)
                    }
                }
            }

            HStack {
                Button {
                    Haptics.success()
                    withAnimation(ScholarTheme.Motion.bouncy) {
                        model.markModule(course: course, chapter: chapter, index: index, completed: !isCompleted)
                    }
                } label: {
                    Label(isCompleted ? "已掌握" : "标记为已掌握", systemImage: isCompleted ? "checkmark.circle.fill" : "circle")
                        .contentTransition(.symbolEffect(.replace))
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
        .padding(24)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ScholarTheme.cornerRadius, style: .continuous)
                .stroke(.primary.opacity(0.055), lineWidth: 1)
        }
        .sheet(isPresented: $showingNote) {
            StudyNoteEditor(course: course, chapter: chapter, point: point, moduleIndex: index)
        }
    }
}

// MARK: - 资源行

private struct ResourceRow: View {
    @EnvironmentObject private var model: AppModel
    let course: Course
    let resource: LearningResource
    let theme: ReadingTheme

    var body: some View {
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
                            .foregroundStyle(theme.textColor)
                        Text(model.cachedURL(for: resource) == nil ? (resource.detail ?? resource.kind.title) : "已下载 · \(resource.detail ?? resource.kind.title)")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryTextColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
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
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

// MARK: - 笔记编辑

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
                        Haptics.success()
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
