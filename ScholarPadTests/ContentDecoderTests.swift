import XCTest
@testable import ScholarPad

final class ContentDecoderTests: XCTestCase {
    func testBundledChaptersJSONDecodes() throws {
        let url = try XCTUnwrap(
            Bundle(for: ContentDecoderTests.self).url(forResource: "chapters", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(CoursePayload.self, from: data)

        XCTAssertEqual(payload.totalChapters, 3)
        XCTAssertEqual(payload.chapters.count, 3)
        XCTAssertEqual(payload.chapters.first?.questions.all.count, 4)
        XCTAssertEqual(payload.courseID, "learning-science-foundations")
        XCTAssertEqual(payload.courseTitle, "高效学习方法")
        XCTAssertEqual(payload.courseAccent, .indigo)
    }

    func testQuestionTypesDecode() throws {
        let data = Data("""
        {
          "id": 1,
          "type": "multiple_choice",
          "question": "测试题",
          "answer": "AC",
          "explanation": "解析",
          "options": {"A": "甲", "B": "乙", "C": "丙"}
        }
        """.utf8)

        let question = try JSONDecoder().decode(Question.self, from: data)
        XCTAssertEqual(question.type, .multipleChoice)
        XCTAssertEqual(question.options?["A"], "甲")
    }

    func testImportedTextRemovesInvisibleAndControlCharacters() throws {
        let data = Data("""
        {
          "id": 1,
          "type": "single_choice",
          "question": "题\u{200B}干\\u0000",
          "answer": "A",
          "options": {"A": "正\u{2060}确"}
        }
        """.utf8)

        let question = try JSONDecoder().decode(Question.self, from: data)

        XCTAssertEqual(question.question, "题干")
        XCTAssertEqual(question.options?["A"], "正确")
    }

    func testRichContentFormatterHidesImportedMarkup() {
        let content = """
        <table><tr><td>数值</td><td>$ \\frac{1}{2} \\times 4 $</td></tr></table>
        """
        let preview = RichContentFormatter.previewText(content)

        XCTAssertFalse(preview.contains("<table"))
        XCTAssertFalse(preview.contains("\\frac"))
        XCTAssertTrue(preview.contains("÷"))
        XCTAssertTrue(preview.contains("×"))
        XCTAssertTrue(RichContentFormatter.previewText("$ B_{12} + x^2 $").contains("B₁₂ + x²"))
    }

    func testShelfAndCloudResourcePersistenceModelsDecode() throws {
        let shelf = LibraryShelf(id: "shelf-1", name: "行测书柜", createdAt: Date(timeIntervalSince1970: 1))
        let resource = CloudResource(
            id: "resource-1",
            title: "课程视频",
            url: try XCTUnwrap(URL(string: "https://example.com/video.mp4")),
            kind: .video,
            detail: "第一讲",
            createdAt: Date(timeIntervalSince1970: 2)
        )

        let shelves = try JSONDecoder().decode([LibraryShelf].self, from: JSONEncoder().encode([shelf]))
        let resources = try JSONDecoder().decode([CloudResource].self, from: JSONEncoder().encode([resource]))

        XCTAssertEqual(shelves.first?.name, "行测书柜")
        XCTAssertEqual(resources.first?.learningResource.kind, .video)
    }

    func testQuestionEvaluatorSupportsChoiceKeysBeyondD() throws {
        let data = Data("""
        {
          "id": 1,
          "type": "multiple_choice",
          "question": "选择所有正确选项",
          "answer": "BEF",
          "options": {
            "A": "甲",
            "B": "乙",
            "C": "丙",
            "D": "丁",
            "E": "戊",
            "F": "己"
          }
        }
        """.utf8)
        let question = try JSONDecoder().decode(Question.self, from: data)

        XCTAssertTrue(QuestionEvaluator.isCorrect(question, selectedAnswers: ["B", "E", "F"]))
        XCTAssertFalse(QuestionEvaluator.isCorrect(question, selectedAnswers: ["B", "E"]))
    }

    func testQuestionEvaluatorHandlesNegativeTrueFalseAnswers() throws {
        let negative = try JSONDecoder().decode(
            Question.self,
            from: Data("""
            {
              "id": 1,
              "type": "true_false",
              "question": "测试判断题",
              "answer": "不正确"
            }
            """.utf8)
        )
        let missing = try JSONDecoder().decode(
            Question.self,
            from: Data("""
            {
              "id": 2,
              "type": "true_false",
              "question": "缺少答案"
            }
            """.utf8)
        )

        XCTAssertTrue(QuestionEvaluator.isCorrect(negative, selectedAnswers: ["错"]))
        XCTAssertFalse(QuestionEvaluator.isCorrect(negative, selectedAnswers: ["对"]))
        XCTAssertFalse(QuestionEvaluator.isCorrect(missing, selectedAnswers: ["错"]))
    }

    func testMissingOptionalFieldsAreTolerated() throws {
        let data = Data("""
        {
          "total_chapters": 99,
          "total_questions": 99,
          "total_kp_modules": 99,
          "chapters": [{
            "chapter_id": 8,
            "chapter_title": "精简章节",
            "knowledge_points": [{"title": "核心概念"}],
            "questions": {
              "single_choice": [{
                "id": 1,
                "type": "single_choice",
                "question": "示例问题",
                "options": {"A": "示例选项"}
              }]
            },
            "stats": {"total_questions": 99}
          }]
        }
        """.utf8)

        let payload = try JSONDecoder().decode(CoursePayload.self, from: data)

        XCTAssertEqual(payload.totalChapters, 1)
        XCTAssertEqual(payload.totalKnowledgeModules, 1)
        XCTAssertEqual(payload.totalQuestions, 1)
        XCTAssertEqual(payload.chapters[0].stats.totalQuestions, 1)
        XCTAssertEqual(payload.chapters[0].knowledgePoints[0].description, "")
    }

    func testSingleChapterJSONImportsAsCourse() async throws {
        let data = Data("""
        {
          "chapter_id": 7,
          "chapter_title": "单章课程",
          "knowledge_points": [{"title": "核心知识"}],
          "questions": {
            "single_choice": [{
              "id": 1,
              "type": "single_choice",
              "question": "示例题",
              "answer": "A",
              "options": {"A": "正确", "B": "错误"}
            }]
          }
        }
        """.utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let course = try await ContentRepository().loadImportedCourse(from: url)

        XCTAssertEqual(course.title, "单章课程")
        XCTAssertEqual(course.subtitle, "单章导入课程")
        XCTAssertEqual(course.payload.totalChapters, 1)
        XCTAssertEqual(course.payload.totalQuestions, 1)
    }

    func testReviewSchedulerExpandsAndResetsInterval() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = ReviewScheduler.updatedItem(
            existing: nil,
            id: "q1",
            courseID: "course",
            chapterID: 1,
            questionType: .singleChoice,
            questionID: 1,
            correct: true,
            now: now
        )
        let second = ReviewScheduler.updatedItem(
            existing: first,
            id: "q1",
            courseID: "course",
            chapterID: 1,
            questionType: .singleChoice,
            questionID: 1,
            correct: true,
            now: now
        )
        let incorrect = ReviewScheduler.updatedItem(
            existing: second,
            id: "q1",
            courseID: "course",
            chapterID: 1,
            questionType: .singleChoice,
            questionID: 1,
            correct: false,
            now: now
        )

        XCTAssertEqual(first.intervalDays, 1)
        XCTAssertEqual(second.intervalDays, 2)
        XCTAssertEqual(incorrect.intervalDays, 0)
        XCTAssertEqual(incorrect.lapses, 1)
        XCTAssertEqual(incorrect.correctStreak, 0)
    }

    func testRemoteCatalogDecodesWithDefaults() throws {
        let data = Data("""
        {
          "courses": [{
            "id": "course-1",
            "title": "在线课程",
            "course_url": "https://example.com/chapters.json"
          }]
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let catalog = try decoder.decode(RemoteCourseCatalog.self, from: data)

        XCTAssertEqual(catalog.version, 1)
        XCTAssertEqual(catalog.courses[0].accent, .indigo)
        XCTAssertEqual(catalog.courses[0].subject, "在线课程")
    }

    func testResourceDownloadRejectsInsecureURL() async throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/video.mp4"))
        let resource = LearningResource(
            id: "video-1",
            title: "示例视频",
            kind: .video,
            url: url,
            detail: nil
        )

        do {
            _ = try await ResourceDownloadService().download(resource)
            XCTFail("HTTP resource should be rejected")
        } catch ResourceDownloadError.insecureURL {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCourseValidatorRejectsDuplicateChapterIDs() throws {
        let data = Data("""
        {
          "chapters": [
            {"chapter_id": 1, "chapter_title": "第一章"},
            {"chapter_id": 1, "chapter_title": "重复章节"}
          ]
        }
        """.utf8)
        let payload = try JSONDecoder().decode(CoursePayload.self, from: data)

        XCTAssertTrue(CourseValidator.issues(in: payload).contains("章节 ID 1 重复"))
    }

    func testCatalogValidatorRejectsInsecureCourseURL() throws {
        let data = Data("""
        {
          "courses": [{
            "id": "course-1",
            "title": "不安全课程",
            "course_url": "http://example.com/chapters.json"
          }]
        }
        """.utf8)
        let catalog = try JSONDecoder().decode(RemoteCourseCatalog.self, from: data)

        XCTAssertEqual(
            CourseValidator.issues(in: catalog),
            ["在线课程“不安全课程”未使用 HTTPS 地址"]
        )
    }

    func testLearningBackupRoundTrip() async throws {
        let backup = LearningBackup(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            progress: ["course::1": ChapterProgress(completedModuleIndexes: [0])],
            studyEvents: [],
            savedItems: ["course::1::single_choice::1"],
            reviewItems: [:],
            notes: [:],
            libraryShelves: nil,
            courseShelfAssignments: nil,
            cloudResources: nil
        )

        let data = try await LearningBackupService().encode(backup)
        let decoded = try JSONDecoder.iso8601.decode(LearningBackup.self, from: data)

        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.progress["course::1"]?.completedModuleIndexes, [0])
        XCTAssertEqual(decoded.savedItems.count, 1)
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
