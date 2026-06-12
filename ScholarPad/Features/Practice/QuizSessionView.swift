import Combine
import SwiftUI

// MARK: - 练习模式

enum QuizMode: String, CaseIterable, Identifiable {
    case sequential, shuffled, browse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sequential: "顺序练习"
        case .shuffled: "乱序练习"
        case .browse: "背题模式"
        }
    }

    var detail: String {
        switch self {
        case .sequential: "按题目原始顺序作答并计入掌握记录"
        case .shuffled: "随机打乱题序，检验真实记忆"
        case .browse: "直接显示答案与解析，适合快速过题"
        }
    }

    var symbol: String {
        switch self {
        case .sequential: "list.number"
        case .shuffled: "shuffle"
        case .browse: "book"
        }
    }
}

// MARK: - 练习会话

struct QuizSessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    let course: Course
    let chapter: Chapter
    let questions: [Question]

    @State private var mode: QuizMode?
    @State private var orderedQuestions: [Question] = []
    @State private var index = 0
    @State private var selectedAnswers: Set<String> = []
    @State private var writtenAnswer = ""
    @State private var showingAnswer = false
    @State private var currentCorrect = false
    @State private var results: [Int: Bool] = [:]
    @State private var isFinished = false
    @State private var showingAnswerSheet = false
    @State private var startedAt = Date()
    @State private var elapsed: TimeInterval = 0
    @State private var activeStartedAt: Date?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: Question? {
        orderedQuestions.indices.contains(index) ? orderedQuestions[index] : nil
    }

    private var correctCount: Int { results.values.filter { $0 }.count }

    var body: some View {
        Group {
            if questions.isEmpty {
                EmptyState(symbol: "questionmark.folder", title: "暂无题目", detail: "本章节还没有可练习的题目")
            } else if mode == nil {
                QuizModePicker(course: course, chapter: chapter, questionCount: questions.count) { picked in
                    start(picked)
                }
            } else if isFinished {
                QuizResultView(
                    course: course,
                    chapter: chapter,
                    results: results,
                    questions: orderedQuestions,
                    elapsed: elapsed,
                    restart: { restart(keepMode: true) },
                    retryWrong: retryWrongQuestions
                )
            } else if let current {
                questionPage(current)
            }
        }
        .background(ScholarTheme.page)
        .navigationTitle(mode == .browse ? "背题模式" : "章节练习")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode != nil && !isFinished {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAnswerSheet = true
                    } label: {
                        Label("答题卡", systemImage: "square.grid.3x3")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAnswerSheet) {
            AnswerSheetView(
                course: course,
                questions: orderedQuestions,
                results: results,
                currentIndex: index
            ) { target in
                jump(to: target)
                showingAnswerSheet = false
            }
        }
        .onReceive(timer) { _ in
            guard mode != nil, !isFinished else { return }
            elapsed = Date().timeIntervalSince(startedAt)
        }
        .onAppear {
            if questions.count <= 1 {
                start(.sequential)
            }
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

    // MARK: - 题目页

    private func questionPage(_ question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                progressHeader(question)
                questionCard(question)

                if showingAnswer {
                    AnswerExplanationCard(
                        question: question,
                        isCorrect: currentCorrect,
                        isObjective: question.type != .shortAnswer,
                        isBrowse: mode == .browse
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                actionBar(question)
            }
            .padding(ScholarTheme.Spacing.pagePadding)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity)
            .animation(ScholarTheme.Motion.snappy, value: showingAnswer)
        }
        .id(index)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private func progressHeader(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(question.type.title, systemImage: question.type.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(course.accent.color)
                Spacer()
                Label(formattedElapsed, systemImage: "stopwatch")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("\(index + 1) / \(orderedQuestions.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(index + 1), total: Double(orderedQuestions.count))
                .tint(course.accent.color)
        }
    }

    private func questionCard(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                Text(question.question)
                    .font(.title2.weight(.bold))
                    .lineSpacing(6)
                Spacer(minLength: 18)
                Button {
                    Haptics.light()
                    model.toggleSaved(course: course, chapter: chapter, question: question)
                } label: {
                    Image(systemName: model.isSaved(course: course, chapter: chapter, question: question) ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .foregroundStyle(course.accent.color)
            }

            switch question.type {
            case .singleChoice, .multipleChoice:
                optionList(question)
            case .trueFalse:
                trueFalseChoices
            case .shortAnswer:
                if mode != .browse {
                    TextEditor(text: $writtenAnswer)
                        .font(.body)
                        .frame(minHeight: 150)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(ScholarTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if writtenAnswer.isEmpty {
                                Text("先写下你的理解，再查看参考答案…")
                                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
        }
        .scholarCard(padding: 26)
        .disabled(showingAnswer && mode != .browse)
    }

    private func optionList(_ question: Question) -> some View {
        VStack(spacing: 12) {
            ForEach((question.options ?? [:]).keys.sorted(), id: \.self) { key in
                ChoiceRow(
                    key: key,
                    text: question.options?[key] ?? "",
                    isSelected: selectedAnswers.contains(key),
                    color: course.accent.color
                ) {
                    Haptics.selection()
                    if question.type == .singleChoice {
                        selectedAnswers = [key]
                    } else if selectedAnswers.contains(key) {
                        selectedAnswers.remove(key)
                    } else {
                        selectedAnswers.insert(key)
                    }
                }
            }
        }
    }

    private var trueFalseChoices: some View {
        HStack(spacing: 14) {
            ForEach(["对", "错"], id: \.self) { value in
                ChoiceRow(
                    key: value == "对" ? "✓" : "×",
                    text: value,
                    isSelected: selectedAnswers.contains(value),
                    color: value == "对" ? .green : .orange
                ) {
                    Haptics.selection()
                    selectedAnswers = [value]
                }
            }
        }
    }

    // MARK: - 操作栏

    private func actionBar(_ question: Question) -> some View {
        HStack {
            Text(statusText(question))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()

            if mode == .browse {
                Button {
                    Haptics.light()
                    goBack()
                } label: {
                    Label("上一题", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(index == 0)
                Button(index == orderedQuestions.count - 1 ? "完成" : "下一题") {
                    Haptics.light()
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .tint(course.accent.color)
            } else if showingAnswer && question.type == .shortAnswer {
                Button("需要复习") { finishShortAnswer(correct: false, question: question) }
                    .buttonStyle(.bordered)
                Button("已经掌握") { finishShortAnswer(correct: true, question: question) }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            } else if showingAnswer {
                Button(index == orderedQuestions.count - 1 ? "查看结果" : "下一题") {
                    Haptics.light()
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .tint(course.accent.color)
            } else {
                Button(question.type == .shortAnswer ? "查看参考答案" : "提交答案") {
                    submit(question)
                }
                .buttonStyle(.borderedProminent)
                .tint(course.accent.color)
                .disabled(question.type == .shortAnswer
                          ? writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          : selectedAnswers.isEmpty)
            }
        }
        .scholarCard(padding: 16)
    }

    private func statusText(_ question: Question) -> String {
        if mode == .browse { return "答案已直接显示，按自己的节奏过题" }
        if showingAnswer {
            if question.type == .shortAnswer { return "请对照参考答案自评" }
            return currentCorrect ? "回答正确" : "继续巩固这个知识点"
        }
        return "作答后查看解析"
    }

    // MARK: - 逻辑

    private func start(_ picked: QuizMode) {
        mode = picked
        orderedQuestions = picked == .shuffled ? questions.shuffled() : questions
        startedAt = Date()
        elapsed = 0
        if picked == .browse {
            showingAnswer = true
        }
    }

    private func submit(_ question: Question) {
        if question.type == .shortAnswer {
            withAnimation(ScholarTheme.Motion.snappy) { showingAnswer = true }
            return
        }

        currentCorrect = QuestionEvaluator.isCorrect(question, selectedAnswers: selectedAnswers)
        results[index] = currentCorrect
        if currentCorrect { Haptics.success() } else { Haptics.error() }
        model.recordAttempt(course: course, chapter: chapter, question: question, correct: currentCorrect)
        withAnimation(ScholarTheme.Motion.snappy) { showingAnswer = true }
    }

    private func finishShortAnswer(correct: Bool, question: Question) {
        results[index] = correct
        if correct { Haptics.success() }
        model.recordAttempt(course: course, chapter: chapter, question: question, correct: correct)
        advance()
    }

    private func advance() {
        if index == orderedQuestions.count - 1 {
            withAnimation(ScholarTheme.Motion.snappy) { isFinished = true }
        } else {
            withAnimation(ScholarTheme.Motion.snappy) {
                index += 1
                resetQuestionState()
            }
        }
    }

    private func goBack() {
        guard index > 0 else { return }
        withAnimation(ScholarTheme.Motion.snappy) {
            index -= 1
            resetQuestionState()
        }
    }

    private func jump(to target: Int) {
        guard orderedQuestions.indices.contains(target) else { return }
        Haptics.selection()
        withAnimation(ScholarTheme.Motion.snappy) {
            index = target
            resetQuestionState()
            // 已作答题目直接展示解析
            if let result = results[target], mode != .browse {
                showingAnswer = true
                currentCorrect = result
            }
        }
    }

    private func resetQuestionState() {
        selectedAnswers = []
        writtenAnswer = ""
        showingAnswer = mode == .browse
        currentCorrect = false
    }

    private func restart(keepMode: Bool) {
        let previousMode = mode
        index = 0
        results = [:]
        isFinished = false
        resetQuestionState()
        if keepMode, let previousMode {
            start(previousMode)
        } else {
            mode = nil
        }
    }

    private func retryWrongQuestions() {
        let wrong = results.filter { !$0.value }.compactMap { entry -> Question? in
            orderedQuestions.indices.contains(entry.key) ? orderedQuestions[entry.key] : nil
        }
        guard !wrong.isEmpty else {
            restart(keepMode: true)
            return
        }
        orderedQuestions = wrong
        index = 0
        results = [:]
        isFinished = false
        startedAt = Date()
        elapsed = 0
        resetQuestionState()
    }

    private var formattedElapsed: String {
        let total = Int(elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
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

// MARK: - 模式选择页

private struct QuizModePicker: View {
    let course: Course
    let chapter: Chapter
    let questionCount: Int
    let onPick: (QuizMode) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(course.accent.color)
                        .symbolRenderingMode(.hierarchical)
                    Text(chapter.chapterTitle)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("共 \(questionCount) 道题 · 选择练习方式")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 30)

                VStack(spacing: 14) {
                    ForEach(QuizMode.allCases) { mode in
                        Button {
                            Haptics.medium()
                            onPick(mode)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: mode.symbol)
                                    .font(.title3)
                                    .foregroundStyle(course.accent.color)
                                    .frame(width: 46, height: 46)
                                    .background(course.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(mode.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            }
                            .scholarCard(padding: 18)
                        }
                        .buttonStyle(.scaling)
                    }
                }
            }
            .padding(ScholarTheme.Spacing.pagePadding)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 答题卡

private struct AnswerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let course: Course
    let questions: [Question]
    let results: [Int: Bool]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        legend(color: .green, text: "答对")
                        legend(color: .red, text: "答错")
                        legend(color: course.accent.color, text: "当前")
                        legend(color: Color(uiColor: .tertiaryLabel), text: "未作答")
                    }
                    .font(.caption)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 12)], spacing: 12) {
                        ForEach(questions.indices, id: \.self) { idx in
                            Button {
                                onSelect(idx)
                            } label: {
                                Text("\(idx + 1)")
                                    .font(.headline.weight(.bold))
                                    .monospacedDigit()
                                    .frame(width: 54, height: 54)
                                    .foregroundStyle(foreground(idx))
                                    .background(background(idx), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        if idx == currentIndex {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(course.accent.color, lineWidth: 2.5)
                                        }
                                    }
                            }
                            .buttonStyle(.scaling)
                        }
                    }
                }
                .padding(24)
            }
            .background(ScholarTheme.page)
            .navigationTitle("答题卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text).foregroundStyle(.secondary)
        }
    }

    private func foreground(_ idx: Int) -> Color {
        results[idx] == nil ? .primary : .white
    }

    private func background(_ idx: Int) -> Color {
        switch results[idx] {
        case .some(true): .green
        case .some(false): .red.opacity(0.85)
        case nil: ScholarTheme.elevated
        }
    }
}

// MARK: - 选项行

private struct ChoiceRow: View {
    let key: String
    let text: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(key)
                    .font(.headline.weight(.bold))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(isSelected ? .white : color)
                    .background(isSelected ? color : color.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? color : Color(uiColor: .tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(13)
            .background(isSelected ? color.opacity(0.08) : ScholarTheme.elevated, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? color.opacity(0.55) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.scaling)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 解析卡片

private struct AnswerExplanationCard: View {
    let question: Question
    let isCorrect: Bool
    let isObjective: Bool
    var isBrowse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: headerSymbol)
                    .foregroundStyle(headerColor)
                Text(headerTitle)
                    .font(.headline)
            }
            if !question.answer.isEmpty {
                LabeledContent("答案") {
                    Text(question.answer)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            if let points = question.answerPoints, !points.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("作答要点")
                        .font(.subheadline.weight(.semibold))
                    ForEach(points, id: \.self) { point in
                        Label(point, systemImage: "circle.fill")
                            .font(.subheadline)
                    }
                }
            }
            if !question.explanation.isEmpty {
                Divider()
                Text(.init(question.explanation))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
            }
        }
        .scholarCard()
    }

    private var headerSymbol: String {
        if isBrowse { return "text.book.closed.fill" }
        if !isObjective { return "text.book.closed.fill" }
        return isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var headerColor: Color {
        if isBrowse || !isObjective { return .indigo }
        return isCorrect ? .green : .orange
    }

    private var headerTitle: String {
        if isBrowse { return "答案与解析" }
        if !isObjective { return "参考答案" }
        return isCorrect ? "回答正确" : "答案与解析"
    }
}

// MARK: - 结果页

private struct QuizResultView: View {
    let course: Course
    let chapter: Chapter
    let results: [Int: Bool]
    let questions: [Question]
    let elapsed: TimeInterval
    let restart: () -> Void
    let retryWrong: () -> Void

    private var correctCount: Int { results.values.filter { $0 }.count }
    private var answeredCount: Int { results.count }
    private var wrongCount: Int { answeredCount - correctCount }
    private var score: Double {
        answeredCount == 0 ? 0 : Double(correctCount) / Double(answeredCount)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 14) {
                    Image(systemName: score >= 0.8 ? "trophy.fill" : "chart.line.uptrend.xyaxis")
                        .font(.system(size: 68))
                        .foregroundStyle(score >= 0.8 ? .orange : course.accent.color)
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(.bounce, value: score)
                    Text(score >= 0.8 ? "掌握得很好" : "练习完成")
                        .font(.largeTitle.weight(.bold))
                    Text(chapter.chapterTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                ProgressRing(value: score, size: 124, lineWidth: 13, color: course.accent.color)

                HStack(spacing: 14) {
                    resultStat(value: "\(correctCount)", title: "答对", color: .green)
                    resultStat(value: "\(wrongCount)", title: "答错", color: wrongCount > 0 ? .red : .secondary)
                    resultStat(value: formattedElapsed, title: "用时", color: course.accent.color)
                }
                .frame(maxWidth: 540)

                VStack(spacing: 12) {
                    if wrongCount > 0 {
                        Button {
                            Haptics.medium()
                            retryWrong()
                        } label: {
                            Label("只练错题（\(wrongCount) 题）", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    if wrongCount > 0 {
                        Button {
                            Haptics.light()
                            restart()
                        } label: {
                            Label("再练一次", systemImage: "gobackward")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(course.accent.color)
                    } else {
                        Button {
                            Haptics.light()
                            restart()
                        } label: {
                            Label("再练一次", systemImage: "gobackward")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(course.accent.color)
                    }
                }
                .frame(maxWidth: 420)
            }
            .padding(30)
            .frame(maxWidth: .infinity)
        }
    }

    private func resultStat(value: String, title: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .scholarCard(padding: 16)
    }

    private var formattedElapsed: String {
        let total = Int(elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
