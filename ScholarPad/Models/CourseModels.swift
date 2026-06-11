import Foundation

struct Course: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var subtitle: String
    var subject: String
    var accent: CourseAccent
    var payload: CoursePayload
    var source: CourseSource
    var catalogID: String? = nil

    var totalQuestions: Int { payload.totalQuestions }
    var totalKnowledgeModules: Int { payload.totalKnowledgeModules }
    var learningResources: [LearningResource] {
        payload.chapters.flatMap { chapter in
            chapter.knowledgePoints.flatMap { $0.resources ?? [] }
        }
    }
}

enum CourseSource: Hashable, Sendable {
    case bundled
    case imported
    case remote(URL)

    var isBundled: Bool {
        if case .bundled = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .bundled: "内置课程"
        case .imported: "本地课程"
        case .remote: "在线课程"
        }
    }
}

enum CourseAccent: String, CaseIterable, Codable, Hashable, Sendable {
    case indigo
    case cyan
    case coral
    case violet
    case mint
}

struct CoursePayload: Codable, Hashable, Sendable {
    let courseID: String?
    let courseTitle: String?
    let courseSubtitle: String?
    let courseSubject: String?
    let courseAccent: CourseAccent?
    let totalChapters: Int
    let totalQuestions: Int
    let totalKnowledgeModules: Int
    let chapters: [Chapter]

    enum CodingKeys: String, CodingKey {
        case courseID = "course_id"
        case courseTitle = "course_title"
        case courseSubtitle = "course_subtitle"
        case courseSubject = "course_subject"
        case courseAccent = "course_accent"
        case totalChapters = "total_chapters"
        case totalQuestions = "total_questions"
        case totalKnowledgeModules = "total_kp_modules"
        case chapters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        courseID = try container.decodeIfPresent(String.self, forKey: .courseID)
        courseTitle = try container.decodeIfPresent(String.self, forKey: .courseTitle)
        courseSubtitle = try container.decodeIfPresent(String.self, forKey: .courseSubtitle)
        courseSubject = try container.decodeIfPresent(String.self, forKey: .courseSubject)
        courseAccent = try? container.decode(CourseAccent.self, forKey: .courseAccent)
        chapters = try container.decodeIfPresent([Chapter].self, forKey: .chapters) ?? []
        totalChapters = chapters.count
        totalQuestions = chapters.reduce(0) { $0 + $1.questions.all.count }
        totalKnowledgeModules = chapters.reduce(0) { $0 + $1.knowledgePoints.count }
    }
}

struct Chapter: Codable, Identifiable, Hashable, Sendable {
    let chapterID: Int
    let chapterTitle: String
    let knowledgePoints: [KnowledgePoint]
    let questions: QuestionBank
    let stats: ChapterStats

    var id: Int { chapterID }

    enum CodingKeys: String, CodingKey {
        case chapterID = "chapter_id"
        case chapterTitle = "chapter_title"
        case knowledgePoints = "knowledge_points"
        case questions
        case stats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chapterID = try container.decode(Int.self, forKey: .chapterID)
        chapterTitle = try container.decodeIfPresent(String.self, forKey: .chapterTitle) ?? "未命名章节"
        knowledgePoints = try container.decodeIfPresent([KnowledgePoint].self, forKey: .knowledgePoints) ?? []
        questions = try container.decodeIfPresent(QuestionBank.self, forKey: .questions) ?? QuestionBank()
        stats = ChapterStats(knowledgePoints: knowledgePoints, questions: questions)
    }
}

struct KnowledgePoint: Codable, Hashable, Sendable {
    let title: String
    let description: String
    let subPoints: [String]
    let resources: [LearningResource]?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case subPoints = "sub_points"
        case resources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名知识点"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        subPoints = try container.decodeIfPresent([String].self, forKey: .subPoints) ?? []
        resources = try container.decodeIfPresent([LearningResource].self, forKey: .resources)
    }
}

struct LearningResource: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let kind: LearningResourceKind
    let url: URL
    let detail: String?
}

enum LearningResourceKind: String, Codable, Hashable, Sendable {
    case video
    case audio
    case document
    case image
    case link

    var title: String {
        switch self {
        case .video: "视频"
        case .audio: "音频"
        case .document: "讲义"
        case .image: "图片"
        case .link: "链接"
        }
    }

    var symbol: String {
        switch self {
        case .video: "play.rectangle.fill"
        case .audio: "waveform"
        case .document: "doc.text.fill"
        case .image: "photo.fill"
        case .link: "link"
        }
    }
}

struct RemoteCourseCatalog: Codable, Sendable {
    let version: Int
    let updatedAt: Date?
    let courses: [RemoteCourseDescriptor]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case courses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        courses = try container.decodeIfPresent([RemoteCourseDescriptor].self, forKey: .courses) ?? []
    }
}

struct RemoteCourseDescriptor: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let subject: String
    let accent: CourseAccent
    let courseURL: URL
    let chapterCount: Int?
    let questionCount: Int?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case subject
        case accent
        case courseURL = "course_url"
        case chapterCount = "chapter_count"
        case questionCount = "question_count"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? id
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? "在线课程"
        accent = (try? container.decode(CourseAccent.self, forKey: .accent)) ?? .indigo
        courseURL = try container.decode(URL.self, forKey: .courseURL)
        chapterCount = try container.decodeIfPresent(Int.self, forKey: .chapterCount)
        questionCount = try container.decodeIfPresent(Int.self, forKey: .questionCount)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct QuestionBank: Codable, Hashable, Sendable {
    let singleChoice: [Question]
    let multipleChoice: [Question]
    let trueFalse: [Question]
    let shortAnswer: [Question]

    var all: [Question] {
        singleChoice + multipleChoice + trueFalse + shortAnswer
    }

    enum CodingKeys: String, CodingKey {
        case singleChoice = "single_choice"
        case multipleChoice = "multiple_choice"
        case trueFalse = "true_false"
        case shortAnswer = "short_answer"
    }

    init(
        singleChoice: [Question] = [],
        multipleChoice: [Question] = [],
        trueFalse: [Question] = [],
        shortAnswer: [Question] = []
    ) {
        self.singleChoice = singleChoice
        self.multipleChoice = multipleChoice
        self.trueFalse = trueFalse
        self.shortAnswer = shortAnswer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        singleChoice = try container.decodeIfPresent([Question].self, forKey: .singleChoice) ?? []
        multipleChoice = try container.decodeIfPresent([Question].self, forKey: .multipleChoice) ?? []
        trueFalse = try container.decodeIfPresent([Question].self, forKey: .trueFalse) ?? []
        shortAnswer = try container.decodeIfPresent([Question].self, forKey: .shortAnswer) ?? []
    }
}

struct Question: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let type: QuestionType
    let question: String
    let answer: String
    let explanation: String
    let options: [String: String]?
    let answerPoints: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case question
        case answer
        case explanation
        case options
        case answerPoints = "answer_points"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        type = try container.decode(QuestionType.self, forKey: .type)
        question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
        answer = try container.decodeIfPresent(String.self, forKey: .answer) ?? ""
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation) ?? ""
        options = try container.decodeIfPresent([String: String].self, forKey: .options)
        answerPoints = try container.decodeIfPresent([String].self, forKey: .answerPoints)
    }
}

enum QuestionType: String, Codable, CaseIterable, Hashable, Sendable {
    case singleChoice = "single_choice"
    case multipleChoice = "multiple_choice"
    case trueFalse = "true_false"
    case shortAnswer = "short_answer"

    var title: String {
        switch self {
        case .singleChoice: "单选题"
        case .multipleChoice: "多选题"
        case .trueFalse: "判断题"
        case .shortAnswer: "简答题"
        }
    }

    var symbol: String {
        switch self {
        case .singleChoice: "checkmark.circle"
        case .multipleChoice: "checklist"
        case .trueFalse: "arrow.left.arrow.right.circle"
        case .shortAnswer: "text.alignleft"
        }
    }
}

struct ChapterStats: Codable, Hashable, Sendable {
    let knowledgeModules: Int
    let singleChoice: Int
    let multipleChoice: Int
    let trueFalse: Int
    let shortAnswer: Int
    let totalQuestions: Int

    enum CodingKeys: String, CodingKey {
        case knowledgeModules = "knowledge_modules"
        case singleChoice = "single_choice"
        case multipleChoice = "multiple_choice"
        case trueFalse = "true_false"
        case shortAnswer = "short_answer"
        case totalQuestions = "total_questions"
    }

    init(knowledgePoints: [KnowledgePoint], questions: QuestionBank) {
        knowledgeModules = knowledgePoints.count
        singleChoice = questions.singleChoice.count
        multipleChoice = questions.multipleChoice.count
        trueFalse = questions.trueFalse.count
        shortAnswer = questions.shortAnswer.count
        totalQuestions = questions.all.count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        knowledgeModules = try container.decodeIfPresent(Int.self, forKey: .knowledgeModules) ?? 0
        singleChoice = try container.decodeIfPresent(Int.self, forKey: .singleChoice) ?? 0
        multipleChoice = try container.decodeIfPresent(Int.self, forKey: .multipleChoice) ?? 0
        trueFalse = try container.decodeIfPresent(Int.self, forKey: .trueFalse) ?? 0
        shortAnswer = try container.decodeIfPresent(Int.self, forKey: .shortAnswer) ?? 0
        totalQuestions = try container.decodeIfPresent(Int.self, forKey: .totalQuestions)
            ?? singleChoice + multipleChoice + trueFalse + shortAnswer
    }
}
