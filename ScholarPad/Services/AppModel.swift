import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: AppSection = .home
    @Published private(set) var courses: [Course] = []
    @Published private(set) var progress: [String: ChapterProgress] = [:]
    @Published private(set) var studyEvents: [StudyEvent] = []
    @Published private(set) var savedItems: Set<String> = []
    @Published private(set) var reviewItems: [String: ReviewItem] = [:]
    @Published private(set) var notes: [String: StudyNote] = [:]
    @Published private(set) var remoteCatalog: RemoteCourseCatalog?
    @Published private(set) var reviewRemindersEnabled = false
    @Published private(set) var offlineResourcePaths: [String: String] = [:]
    @Published var isLoading = false
    @Published var notice: String?
    @Published var remoteURLString: String = "" {
        didSet { defaults.set(remoteURLString, forKey: Keys.remoteURL) }
    }
    @Published var catalogURLString: String = "" {
        didSet { defaults.set(catalogURLString, forKey: Keys.catalogURL) }
    }

    let network = NetworkMonitor()
    private let repository = ContentRepository()
    private let reminderService = ReviewReminderService()
    private let resourceDownloadService = ResourceDownloadService()
    private let backupService = LearningBackupService()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let progress = "scholarpad.progress.v1"
        static let studyEvents = "scholarpad.study-events.v1"
        static let savedItems = "scholarpad.saved-items.v1"
        static let reviewItems = "scholarpad.review-items.v1"
        static let notes = "scholarpad.notes.v1"
        static let remoteURL = "scholarpad.remote-url.v1"
        static let catalogURL = "scholarpad.catalog-url.v1"
        static let reviewReminders = "scholarpad.review-reminders.v1"
        static let offlineResources = "scholarpad.offline-resources.v1"
    }

    init() {
        remoteURLString = defaults.string(forKey: Keys.remoteURL) ?? ""
        catalogURLString = defaults.string(forKey: Keys.catalogURL) ?? ""
        progress = Self.decode([String: ChapterProgress].self, from: defaults.data(forKey: Keys.progress)) ?? [:]
        studyEvents = Self.decode([StudyEvent].self, from: defaults.data(forKey: Keys.studyEvents)) ?? []
        savedItems = Self.decode(Set<String>.self, from: defaults.data(forKey: Keys.savedItems)) ?? []
        reviewItems = Self.decode([String: ReviewItem].self, from: defaults.data(forKey: Keys.reviewItems)) ?? [:]
        notes = Self.decode([String: StudyNote].self, from: defaults.data(forKey: Keys.notes)) ?? [:]
        reviewRemindersEnabled = defaults.bool(forKey: Keys.reviewReminders)
        offlineResourcePaths = Self.decode([String: String].self, from: defaults.data(forKey: Keys.offlineResources)) ?? [:]
    }

    func bootstrap() async {
        guard courses.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let validOfflinePaths = offlineResourcePaths.filter {
            FileManager.default.fileExists(atPath: $0.value)
        }
        if validOfflinePaths.count != offlineResourcePaths.count {
            offlineResourcePaths = validOfflinePaths
            persist()
        }

        let cached = (try? await repository.loadCachedCourses()) ?? []
        remoteCatalog = try? await repository.loadCachedCatalog()

        do {
            let bundled = try await repository.loadBundledCourse()
            courses = [bundled] + cached.filter { $0.id != bundled.id }
        } catch {
            courses = cached
            if courses.isEmpty {
                notice = error.localizedDescription
            }
        }
    }

    func importCourse(from url: URL) async {
        await importCourses(from: [url])
    }

    func importCourses(from urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        var importedCount = 0
        var firstErrorMessage: String?
        for url in urls {
            do {
                let course = try await repository.loadImportedCourse(from: url)
                try await repository.storeCachedCourse(course)
                upsert(course)
                importedCount += 1
            } catch {
                firstErrorMessage = firstErrorMessage ?? error.localizedDescription
            }
        }

        if importedCount > 0 {
            selectedSection = .courses
            notice = firstErrorMessage == nil
                ? "已导入 \(importedCount) 门课程"
                : "已导入 \(importedCount) 门课程，部分文件失败：\(firstErrorMessage ?? "")"
        } else {
            notice = firstErrorMessage ?? "没有可导入的课程文件"
        }
    }

    func syncRemoteCourse() async {
        guard network.isConnected else {
            notice = "当前处于离线状态"
            return
        }
        guard let url = secureURL(from: remoteURLString) else {
            notice = "请输入有效的 HTTPS 课程地址"
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let course = try await repository.loadRemoteCourse(from: url)
            try await repository.storeCachedCourse(course)
            upsert(course)
            notice = "在线课程同步完成"
        } catch {
            notice = error.localizedDescription
        }
    }

    func refreshRemoteCatalog() async {
        guard network.isConnected else {
            notice = "当前处于离线状态"
            return
        }
        guard let url = secureURL(from: catalogURLString) else {
            notice = "请输入有效的 HTTPS 课程目录地址"
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let catalog = try await repository.loadRemoteCatalog(from: url)
            try await repository.storeCachedCatalog(catalog)
            remoteCatalog = catalog
            selectedSection = .online
        } catch {
            notice = error.localizedDescription
        }
    }

    func installRemoteCourse(_ descriptor: RemoteCourseDescriptor) async {
        guard descriptor.courseURL.scheme?.lowercased() == "https", descriptor.courseURL.host?.isEmpty == false else {
            notice = "课程地址必须使用 HTTPS"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let course = try await repository.loadRemoteCourse(descriptor)
            try await repository.storeCachedCourse(course)
            upsert(course)
            notice = "已安装“\(course.title)”并可离线学习"
        } catch {
            notice = error.localizedDescription
        }
    }

    func isInstalled(_ descriptor: RemoteCourseDescriptor) -> Bool {
        courses.contains { course in
            if course.catalogID == descriptor.id || course.payload.courseID == descriptor.id {
                return true
            }
            if case .remote(let url) = course.source {
                return url == descriptor.courseURL
            }
            return false
        }
    }

    func course(id: String) -> Course? {
        courses.first { $0.id == id }
    }

    func chapter(courseID: String, chapterID: Int) -> Chapter? {
        course(id: courseID)?.payload.chapters.first { $0.id == chapterID }
    }

    func deleteCourse(_ course: Course) async {
        guard !course.source.isBundled else {
            notice = "内置课程不能删除"
            return
        }
        do {
            try await repository.deleteCachedCourse(id: course.id)
            courses.removeAll { $0.id == course.id }
            for resource in course.learningResources {
                let stillUsed = courses.contains {
                    $0.learningResources.contains { $0.url == resource.url }
                }
                if !stillUsed, let localURL = cachedURL(for: resource) {
                    try? await resourceDownloadService.remove(at: localURL)
                    offlineResourcePaths.removeValue(forKey: resource.url.absoluteString)
                }
            }
            let prefix = "\(course.id)::"
            progress = progress.filter { !$0.key.hasPrefix(prefix) }
            studyEvents.removeAll { $0.courseID == course.id }
            savedItems = Set(savedItems.filter { !$0.hasPrefix(prefix) })
            reviewItems = reviewItems.filter { !$0.key.hasPrefix(prefix) }
            notes = notes.filter { !$0.key.hasPrefix(prefix) }
            persist()
            notice = "已删除“\(course.title)”"
        } catch {
            notice = error.localizedDescription
        }
    }

    func clearLearningData() {
        progress.removeAll()
        studyEvents.removeAll()
        savedItems.removeAll()
        reviewItems.removeAll()
        notes.removeAll()
        persist()
        notice = "学习记录已重置，课程内容仍然保留"
    }

    func setReviewReminders(enabled: Bool) async {
        if enabled {
            do {
                let granted = try await reminderService.enableDailyReminder()
                reviewRemindersEnabled = granted
                defaults.set(granted, forKey: Keys.reviewReminders)
                if !granted {
                    notice = "通知权限未开启，可在系统设置中允许学程发送提醒"
                }
            } catch {
                reviewRemindersEnabled = false
                defaults.set(false, forKey: Keys.reviewReminders)
                notice = "无法启用复习提醒：\(error.localizedDescription)"
            }
        } else {
            reminderService.disableDailyReminder()
            reviewRemindersEnabled = false
            defaults.set(false, forKey: Keys.reviewReminders)
        }
    }

    func cachedURL(for resource: LearningResource) -> URL? {
        guard let path = offlineResourcePaths[resource.url.absoluteString],
              FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    func downloadResource(_ resource: LearningResource) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let localURL = try await resourceDownloadService.download(resource)
            offlineResourcePaths[resource.url.absoluteString] = localURL.path
            persist()
            notice = "“\(resource.title)”已可离线使用"
        } catch {
            notice = error.localizedDescription
        }
    }

    func removeDownloadedResource(_ resource: LearningResource) async {
        guard let localURL = cachedURL(for: resource) else { return }
        do {
            try await resourceDownloadService.remove(at: localURL)
            offlineResourcePaths.removeValue(forKey: resource.url.absoluteString)
            persist()
        } catch {
            notice = error.localizedDescription
        }
    }

    func clearDownloadedResources() async {
        do {
            try await resourceDownloadService.clearAll()
            offlineResourcePaths.removeAll()
            persist()
            notice = "离线资源缓存已清理"
        } catch {
            notice = error.localizedDescription
        }
    }

    func makeBackupData() async -> Data? {
        let backup = LearningBackup(
            version: 1,
            exportedAt: Date(),
            progress: progress,
            studyEvents: studyEvents,
            savedItems: savedItems,
            reviewItems: reviewItems,
            notes: notes
        )
        do {
            return try await backupService.encode(backup)
        } catch {
            notice = "无法生成学习备份：\(error.localizedDescription)"
            return nil
        }
    }

    func restoreBackup(from url: URL) async {
        do {
            let backup = try await backupService.decode(from: url)
            progress = backup.progress
            studyEvents = backup.studyEvents
            savedItems = backup.savedItems
            reviewItems = backup.reviewItems
            notes = backup.notes
            persist()
            notice = "学习记录恢复完成"
        } catch {
            notice = "无法恢复学习备份：\(error.localizedDescription)"
        }
    }

    func progress(for course: Course, chapter: Chapter) -> ChapterProgress {
        progress[chapterKey(courseID: course.id, chapterID: chapter.id)] ?? ChapterProgress()
    }

    func completion(for course: Course, chapter: Chapter) -> Double {
        guard !chapter.knowledgePoints.isEmpty else { return 0 }
        let value = progress(for: course, chapter: chapter).completedModuleIndexes.count
        return min(Double(value) / Double(chapter.knowledgePoints.count), 1)
    }

    func courseCompletion(_ course: Course) -> Double {
        let totalModules = course.payload.chapters.reduce(0) { $0 + $1.knowledgePoints.count }
        guard totalModules > 0 else { return 0 }
        let completedModules = course.payload.chapters.reduce(0) {
            $0 + progress(for: course, chapter: $1).completedModuleIndexes.count
        }
        return min(Double(completedModules) / Double(totalModules), 1)
    }

    func markModule(course: Course, chapter: Chapter, index: Int, completed: Bool) {
        let key = chapterKey(courseID: course.id, chapterID: chapter.id)
        var value = progress[key] ?? ChapterProgress()
        if completed {
            value.completedModuleIndexes.insert(index)
        } else {
            value.completedModuleIndexes.remove(index)
        }
        value.lastStudiedAt = Date()
        progress[key] = value
        persist()
    }

    func recordStudy(course: Course, chapter: Chapter, seconds: TimeInterval) {
        guard seconds >= 5 else { return }
        let key = chapterKey(courseID: course.id, chapterID: chapter.id)
        var value = progress[key] ?? ChapterProgress()
        value.studySeconds += seconds
        value.lastStudiedAt = Date()
        progress[key] = value
        studyEvents.append(StudyEvent(id: UUID(), date: Date(), seconds: seconds, courseID: course.id))
        studyEvents = Array(studyEvents.suffix(500))
        persist()
    }

    func recordAttempt(course: Course, chapter: Chapter, question: Question, correct: Bool) {
        let key = chapterKey(courseID: course.id, chapterID: chapter.id)
        let questionKey = self.questionKey(courseID: course.id, chapterID: chapter.id, question: question)
        var value = progress[key] ?? ChapterProgress()
        value.completedQuestionKeys.insert(questionKey)
        if correct {
            value.correctQuestionKeys.insert(questionKey)
        } else {
            value.correctQuestionKeys.remove(questionKey)
        }
        value.lastStudiedAt = Date()
        progress[key] = value
        updateReviewSchedule(
            course: course,
            chapter: chapter,
            question: question,
            correct: correct
        )
        persist()
    }

    func toggleSaved(course: Course, chapter: Chapter, question: Question) {
        let key = questionKey(courseID: course.id, chapterID: chapter.id, question: question)
        if savedItems.contains(key) {
            savedItems.remove(key)
        } else {
            savedItems.insert(key)
        }
        persist()
    }

    func isSaved(course: Course, chapter: Chapter, question: Question) -> Bool {
        savedItems.contains(questionKey(courseID: course.id, chapterID: chapter.id, question: question))
    }

    func savedQuestions() -> [QuestionContext] {
        courses.flatMap { course in
            course.payload.chapters.flatMap { chapter in
                chapter.questions.all.compactMap { question in
                    guard isSaved(course: course, chapter: chapter, question: question) else { return nil }
                    return QuestionContext(
                        id: questionKey(courseID: course.id, chapterID: chapter.id, question: question),
                        course: course,
                        chapter: chapter,
                        question: question
                    )
                }
            }
        }
    }

    func dueReviewQuestions(now: Date = Date()) -> [QuestionContext] {
        contexts(for: reviewItems.values
            .filter { $0.nextReviewAt <= now }
            .sorted { $0.nextReviewAt < $1.nextReviewAt })
    }

    func weakQuestions() -> [QuestionContext] {
        contexts(for: reviewItems.values
            .filter { $0.lapses > 0 && $0.correctStreak == 0 }
            .sorted { $0.lastReviewedAt > $1.lastReviewedAt })
    }

    func note(course: Course, chapter: Chapter, moduleIndex: Int) -> StudyNote? {
        notes[noteKey(courseID: course.id, chapterID: chapter.id, moduleIndex: moduleIndex)]
    }

    func saveNote(course: Course, chapter: Chapter, moduleIndex: Int, text: String) {
        let key = noteKey(courseID: course.id, chapterID: chapter.id, moduleIndex: moduleIndex)
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            notes.removeValue(forKey: key)
        } else {
            notes[key] = StudyNote(
                id: key,
                courseID: course.id,
                chapterID: chapter.id,
                moduleIndex: moduleIndex,
                text: cleaned,
                updatedAt: Date()
            )
        }
        persist()
    }

    func allNotes() -> [StudyNoteContext] {
        notes.values.compactMap { note in
            guard let course = course(id: note.courseID),
                  let chapter = chapter(courseID: note.courseID, chapterID: note.chapterID),
                  chapter.knowledgePoints.indices.contains(note.moduleIndex) else {
                return nil
            }
            return StudyNoteContext(
                note: note,
                course: course,
                chapter: chapter,
                knowledgePoint: chapter.knowledgePoints[note.moduleIndex]
            )
        }
        .sorted { $0.note.updatedAt > $1.note.updatedAt }
    }

    func search(_ query: String) -> [SearchResult] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }

        return courses.flatMap { course in
            course.payload.chapters.flatMap { chapter -> [SearchResult] in
                var results: [SearchResult] = []
                if chapter.chapterTitle.localizedCaseInsensitiveContains(term) {
                    results.append(SearchResult(
                        id: "\(course.id)-\(chapter.id)-chapter",
                        kind: .chapter,
                        title: chapter.chapterTitle,
                        detail: course.title,
                        courseID: course.id,
                        chapterID: chapter.id
                    ))
                }
                for (index, point) in chapter.knowledgePoints.enumerated()
                where ([point.title, point.description] + point.subPoints).contains(where: { $0.localizedCaseInsensitiveContains(term) }) {
                    results.append(SearchResult(
                        id: "\(course.id)-\(chapter.id)-kp-\(index)",
                        kind: .knowledgePoint,
                        title: point.title,
                        detail: chapter.chapterTitle,
                        courseID: course.id,
                        chapterID: chapter.id,
                        moduleIndex: index
                    ))
                }
                for (index, point) in chapter.knowledgePoints.enumerated() {
                    guard let note = note(course: course, chapter: chapter, moduleIndex: index),
                          note.text.localizedCaseInsensitiveContains(term) else {
                        continue
                    }
                    results.append(SearchResult(
                        id: "\(course.id)-\(chapter.id)-note-\(index)",
                        kind: .note,
                        title: point.title,
                        detail: "学习笔记 · \(note.text)",
                        courseID: course.id,
                        chapterID: chapter.id,
                        moduleIndex: index
                    ))
                }
                for question in chapter.questions.all
                where question.question.localizedCaseInsensitiveContains(term) {
                    results.append(SearchResult(
                        id: "\(course.id)-\(chapter.id)-q-\(question.type.rawValue)-\(question.id)",
                        kind: .question,
                        title: question.question,
                        detail: "\(chapter.chapterTitle) · \(question.type.title)",
                        courseID: course.id,
                        chapterID: chapter.id
                    ))
                }
                return results
            }
        }
    }

    var totalStudySeconds: TimeInterval {
        studyEvents.reduce(0) { $0 + $1.seconds }
    }

    var attemptedQuestions: Int {
        progress.values.reduce(0) { $0 + $1.completedQuestionKeys.count }
    }

    var correctQuestions: Int {
        progress.values.reduce(0) { $0 + $1.correctQuestionKeys.count }
    }

    var streakDays: Int {
        let calendar = Calendar.current
        let days = Set(studyEvents.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var date = calendar.startOfDay(for: Date())
        while days.contains(date) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return streak
    }

    func dailyMinutes(days: Int = 7) -> [(Date, Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = studyEvents
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0.0) { $0 + $1.seconds / 60 }
            return (date, total)
        }
    }

    private func upsert(_ course: Course) {
        if let index = courses.firstIndex(where: { $0.id == course.id }) {
            courses[index] = course
        } else {
            courses.append(course)
        }
    }

    private func secureURL(from string: String) -> URL? {
        guard let url = URL(string: string),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        return url
    }

    private func chapterKey(courseID: String, chapterID: Int) -> String {
        "\(courseID)::\(chapterID)"
    }

    private func questionKey(courseID: String, chapterID: Int, question: Question) -> String {
        "\(courseID)::\(chapterID)::\(question.type.rawValue)::\(question.id)"
    }

    private func noteKey(courseID: String, chapterID: Int, moduleIndex: Int) -> String {
        "\(courseID)::\(chapterID)::module::\(moduleIndex)"
    }

    private func updateReviewSchedule(course: Course, chapter: Chapter, question: Question, correct: Bool) {
        let key = questionKey(courseID: course.id, chapterID: chapter.id, question: question)
        reviewItems[key] = ReviewScheduler.updatedItem(
            existing: reviewItems[key],
            id: key,
            courseID: course.id,
            chapterID: chapter.id,
            questionType: question.type,
            questionID: question.id,
            correct: correct
        )
    }

    private func contexts<S: Sequence>(for items: S) -> [QuestionContext] where S.Element == ReviewItem {
        items.compactMap { item in
            guard let course = course(id: item.courseID),
                  let chapter = chapter(courseID: item.courseID, chapterID: item.chapterID),
                  let question = chapter.questions.all.first(where: {
                      $0.id == item.questionID && $0.type == item.questionType
                  }) else {
                return nil
            }
            return QuestionContext(id: item.id, course: course, chapter: chapter, question: question)
        }
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(progress), forKey: Keys.progress)
        defaults.set(try? JSONEncoder().encode(studyEvents), forKey: Keys.studyEvents)
        defaults.set(try? JSONEncoder().encode(savedItems), forKey: Keys.savedItems)
        defaults.set(try? JSONEncoder().encode(reviewItems), forKey: Keys.reviewItems)
        defaults.set(try? JSONEncoder().encode(notes), forKey: Keys.notes)
        defaults.set(try? JSONEncoder().encode(offlineResourcePaths), forKey: Keys.offlineResources)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
