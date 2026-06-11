import SwiftUI

struct PracticeHubView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    practiceHero

                    reviewDeck

                    SectionHeading(title: "专项练习", subtitle: "按题型集中训练")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16)], spacing: 16) {
                        ForEach(QuestionType.allCases, id: \.self) { type in
                            NavigationLink {
                                PracticeTypeListView(type: type)
                            } label: {
                                PracticeTypeCard(type: type, count: questionCount(type))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SectionHeading(title: "章节练习", subtitle: "跟随课程进度巩固知识")
                    chapterPracticeList
                }
                .padding(28)
                .frame(maxWidth: 1320, alignment: .leading)
            }
            .navigationTitle("题目练习")
        }
    }

    private var reviewDeck: some View {
        NavigationLink {
            ReviewQueueView()
        } label: {
            HStack(spacing: 20) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(
                        LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日复习队列")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("到期 \(model.dueReviewQuestions().count) 题 · 弱项 \(model.weakQuestions().count) 题")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.dueReviewQuestions().isEmpty ? "查看" : "开始复习")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .scholarCard()
        }
        .buttonStyle(.plain)
    }

    private var practiceHero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("用主动回忆强化掌握")
                    .font(.largeTitle.weight(.bold))
                Text("每道题都保留答案解析、答题记录与收藏状态。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Label("已完成 \(model.attemptedQuestions)", systemImage: "checkmark.circle.fill")
                    Label(accuracyText, systemImage: "scope")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.indigo)
                .padding(.top, 4)
            }
            Spacer()
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 72))
                .foregroundStyle(.indigo)
                .symbolRenderingMode(.hierarchical)
        }
        .scholarCard()
    }

    private var chapterPracticeList: some View {
        LazyVStack(spacing: 14) {
            ForEach(model.courses) { course in
                ForEach(course.payload.chapters.filter { !$0.questions.all.isEmpty }) { chapter in
                    NavigationLink {
                        QuizSessionView(course: course, chapter: chapter, questions: chapter.questions.all)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(course.accent.color)
                                .frame(width: 50, height: 50)
                                .background(course.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(chapter.chapterTitle)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(course.title) · \(chapter.questions.all.count) 道题")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(course.accent.color)
                        }
                        .scholarCard(padding: 15)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func questionCount(_ type: QuestionType) -> Int {
        model.courses.reduce(0) { partial, course in
            partial + course.payload.chapters.reduce(0) { count, chapter in
                count + chapter.questions.all.filter { $0.type == type }.count
            }
        }
    }

    private var accuracyText: String {
        guard model.attemptedQuestions > 0 else { return "正确率待积累" }
        let accuracy = Double(model.correctQuestions) / Double(model.attemptedQuestions)
        return "正确率 \(accuracy.formatted(.percent.precision(.fractionLength(0))))"
    }
}

struct ReviewQueueView: View {
    @EnvironmentObject private var model: AppModel

    private var due: [QuestionContext] {
        model.dueReviewQuestions()
    }

    private var additionalWeak: [QuestionContext] {
        let dueIDs = Set(due.map(\.id))
        return model.weakQuestions().filter { !dueIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if due.isEmpty && additionalWeak.isEmpty {
                EmptyState(
                    symbol: "checkmark.circle",
                    title: "复习任务已完成",
                    detail: "完成更多练习后，系统会根据答题结果安排间隔复习"
                )
            } else {
                List {
                    if !due.isEmpty {
                        Section("今日到期") {
                            ForEach(due) { context in
                                reviewLink(context)
                            }
                        }
                    }
                    if !additionalWeak.isEmpty {
                        Section("薄弱题目") {
                            ForEach(additionalWeak) { context in
                                reviewLink(context)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("复习队列")
    }

    private func reviewLink(_ context: QuestionContext) -> some View {
        NavigationLink {
            QuizSessionView(
                course: context.course,
                chapter: context.chapter,
                questions: [context.question]
            )
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(context.question.question)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(context.chapter.chapterTitle) · \(context.question.type.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct PracticeTypeCard: View {
    let type: QuestionType
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: type.symbol)
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 48, height: 48)
                .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(type.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text("\(count) 道题目")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scholarCard()
    }
}

private struct PracticeTypeListView: View {
    @EnvironmentObject private var model: AppModel
    let type: QuestionType

    var body: some View {
        List {
            ForEach(model.courses) { course in
                Section(course.title) {
                    ForEach(course.payload.chapters) { chapter in
                        let questions = chapter.questions.all.filter { $0.type == type }
                        if !questions.isEmpty {
                            NavigationLink {
                                QuizSessionView(course: course, chapter: chapter, questions: questions)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(chapter.chapterTitle)
                                        .font(.headline)
                                    Text("\(questions.count) 道\(type.title)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(type.title)
    }
}
