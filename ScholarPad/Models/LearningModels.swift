import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case courses
    case online
    case practice
    case search
    case saved
    case notes
    case progress
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "学习首页"
        case .courses: "我的课程"
        case .online: "在线课程库"
        case .practice: "题目练习"
        case .search: "全局搜索"
        case .saved: "我的收藏"
        case .notes: "学习笔记"
        case .progress: "学习报告"
        case .settings: "设置"
        }
    }

    var symbol: String {
        switch self {
        case .home: "square.grid.2x2"
        case .courses: "books.vertical"
        case .online: "network"
        case .practice: "checkmark.seal"
        case .search: "magnifyingglass"
        case .saved: "bookmark"
        case .notes: "note.text"
        case .progress: "chart.xyaxis.line"
        case .settings: "gearshape"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .home: "square.grid.2x2.fill"
        case .courses: "books.vertical.fill"
        case .online: "network"
        case .practice: "checkmark.seal.fill"
        case .search: "magnifyingglass"
        case .saved: "bookmark.fill"
        case .notes: "note.text"
        case .progress: "chart.xyaxis.line"
        case .settings: "gearshape.fill"
        }
    }
}

struct ChapterProgress: Codable, Hashable, Sendable {
    var completedModuleIndexes: Set<Int> = []
    var completedQuestionKeys: Set<String> = []
    var correctQuestionKeys: Set<String> = []
    var studySeconds: TimeInterval = 0
    var lastStudiedAt: Date?
}

struct StudyEvent: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let seconds: TimeInterval
    let courseID: String
}

struct ReviewItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let courseID: String
    let chapterID: Int
    let questionType: QuestionType
    let questionID: Int
    var nextReviewAt: Date
    var intervalDays: Int
    var correctStreak: Int
    var lapses: Int
    var lastReviewedAt: Date
}

struct StudyNote: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let courseID: String
    let chapterID: Int
    let moduleIndex: Int
    var text: String
    var updatedAt: Date
}

struct LearningBackup: Codable, Sendable {
    let version: Int
    let exportedAt: Date
    let progress: [String: ChapterProgress]
    let studyEvents: [StudyEvent]
    let savedItems: Set<String>
    let reviewItems: [String: ReviewItem]
    let notes: [String: StudyNote]
}

struct QuestionContext: Identifiable, Hashable, Sendable {
    let id: String
    let course: Course
    let chapter: Chapter
    let question: Question
}

struct StudyNoteContext: Identifiable, Hashable, Sendable {
    var id: String { note.id }
    let note: StudyNote
    let course: Course
    let chapter: Chapter
    let knowledgePoint: KnowledgePoint
}

struct SearchResult: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case chapter
        case knowledgePoint
        case question
        case note
    }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let courseID: String
    let chapterID: Int
    let moduleIndex: Int?

    init(
        id: String,
        kind: Kind,
        title: String,
        detail: String,
        courseID: String,
        chapterID: Int,
        moduleIndex: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.courseID = courseID
        self.chapterID = chapterID
        self.moduleIndex = moduleIndex
    }
}

struct CourseImportPreview: Identifiable, Hashable, Sendable {
    let id: String
    let fileName: String
    var course: Course?
    let isUpdate: Bool
    let errorMessage: String?
}
