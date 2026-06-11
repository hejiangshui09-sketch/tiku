import SwiftUI

struct QuizSessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    let course: Course
    let chapter: Chapter
    let questions: [Question]

    @State private var index = 0
    @State private var selectedAnswers: Set<String> = []
    @State private var writtenAnswer = ""
    @State private var showingAnswer = false
    @State private var currentCorrect = false
    @State private var correctCount = 0
    @State private var isFinished = false
    @State private var activeStartedAt: Date?

    private var current: Question? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var body: some View {
        Group {
            if questions.isEmpty {
                EmptyState(symbol: "questionmark.folder", title: "暂无题目", detail: "本章节还没有可练习的题目")
            } else if isFinished {
                QuizResultView(
                    course: course,
                    chapter: chapter,
                    correctCount: correctCount,
                    total: questions.count,
                    restart: restart
                )
            } else if let current {
                questionPage(current)
            }
        }
        .background(ScholarTheme.page)
        .navigationTitle("章节练习")
        .navigationBarTitleDisplayMode(.inline)
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

    private func questionPage(_ question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                progressHeader(question)
                questionCard(question)

                if showingAnswer {
                    AnswerExplanationCard(
                        question: question,
                        isCorrect: currentCorrect,
                        isObjective: question.type != .shortAnswer
                    )
                }

                actionBar(question)
            }
            .padding(28)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func progressHeader(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(question.type.title, systemImage: question.type.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(course.accent.color)
                Spacer()
                Text("\(index + 1) / \(questions.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(index + 1), total: Double(questions.count))
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
                    model.toggleSaved(course: course, chapter: chapter, question: question)
                } label: {
                    Image(systemName: model.isSaved(course: course, chapter: chapter, question: question) ? "bookmark.fill" : "bookmark")
                        .font(.title3)
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
                TextEditor(text: $writtenAnswer)
                    .font(.body)
                    .frame(minHeight: 150)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(ScholarTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if writtenAnswer.isEmpty {
                            Text("先写下你的理解，再查看参考答案…")
                                .foregroundStyle(.tertiary)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .scholarCard(padding: 26)
        .disabled(showingAnswer)
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
                    selectedAnswers = [value]
                }
            }
        }
    }

    private func actionBar(_ question: Question) -> some View {
        HStack {
            Text(showingAnswer ? (question.type == .shortAnswer ? "请对照参考答案自评" : currentCorrect ? "回答正确" : "继续巩固这个知识点") : "作答后查看解析")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()

            if showingAnswer && question.type == .shortAnswer {
                Button("需要复习") { finishShortAnswer(correct: false, question: question) }
                    .buttonStyle(.bordered)
                Button("已经掌握") { finishShortAnswer(correct: true, question: question) }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            } else if showingAnswer {
                Button(index == questions.count - 1 ? "查看结果" : "下一题") {
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
                .disabled(question.type == .shortAnswer ? writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : selectedAnswers.isEmpty)
            }
        }
        .scholarCard(padding: 16)
    }

    private func submit(_ question: Question) {
        if question.type == .shortAnswer {
            showingAnswer = true
            return
        }

        currentCorrect = answerMatches(question)
        if currentCorrect { correctCount += 1 }
        model.recordAttempt(course: course, chapter: chapter, question: question, correct: currentCorrect)
        withAnimation(.snappy) { showingAnswer = true }
    }

    private func finishShortAnswer(correct: Bool, question: Question) {
        if correct { correctCount += 1 }
        model.recordAttempt(course: course, chapter: chapter, question: question, correct: correct)
        advance()
    }

    private func answerMatches(_ question: Question) -> Bool {
        switch question.type {
        case .singleChoice, .multipleChoice:
            return Set(question.answer.uppercased().filter { "ABCD".contains($0) }.map { String($0) }) == selectedAnswers
        case .trueFalse:
            let answer = question.answer
            let expected = (answer.contains("对") || answer.lowercased().contains("true") || answer.contains("正确")) ? "对" : "错"
            return selectedAnswers == [expected]
        case .shortAnswer:
            return false
        }
    }

    private func advance() {
        if index == questions.count - 1 {
            withAnimation(.snappy) { isFinished = true }
        } else {
            index += 1
            selectedAnswers = []
            writtenAnswer = ""
            showingAnswer = false
            currentCorrect = false
        }
    }

    private func restart() {
        index = 0
        selectedAnswers = []
        writtenAnswer = ""
        showingAnswer = false
        currentCorrect = false
        correctCount = 0
        isFinished = false
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
                    .foregroundStyle(isSelected ? color : .tertiary)
            }
            .padding(13)
            .background(isSelected ? color.opacity(0.08) : ScholarTheme.elevated, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? color.opacity(0.55) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct AnswerExplanationCard: View {
    let question: Question
    let isCorrect: Bool
    let isObjective: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: isObjective ? (isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill") : "text.book.closed.fill")
                    .foregroundStyle(isObjective ? (isCorrect ? .green : .orange) : .indigo)
                Text(isObjective ? (isCorrect ? "回答正确" : "答案与解析") : "参考答案")
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
}

private struct QuizResultView: View {
    let course: Course
    let chapter: Chapter
    let correctCount: Int
    let total: Int
    let restart: () -> Void

    private var score: Double {
        total == 0 ? 0 : Double(correctCount) / Double(total)
    }

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: score >= 0.8 ? "trophy.fill" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 72))
                .foregroundStyle(score >= 0.8 ? .orange : course.accent.color)
                .symbolRenderingMode(.hierarchical)
            Text(score >= 0.8 ? "掌握得很好" : "练习完成")
                .font(.largeTitle.weight(.bold))
            Text(chapter.chapterTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
            ProgressRing(value: score, size: 112, lineWidth: 12, color: course.accent.color)
            Text("答对 \(correctCount) / \(total) 题")
                .font(.title3.weight(.semibold))
            Button("再练一次", action: restart)
                .buttonStyle(.borderedProminent)
                .tint(course.accent.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}
