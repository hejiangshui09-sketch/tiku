import Foundation

enum CourseValidator {
    static func issues(in payload: CoursePayload) -> [String] {
        var issues: [String] = []
        var chapterIDs = Set<Int>()

        for chapter in payload.chapters {
            if !chapterIDs.insert(chapter.id).inserted {
                issues.append("章节 ID \(chapter.id) 重复")
            }
            if chapter.chapterTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("章节 \(chapter.id) 缺少标题")
            }

            validateQuestions(chapter.questions.singleChoice, label: "单选题", chapter: chapter, issues: &issues)
            validateQuestions(chapter.questions.multipleChoice, label: "多选题", chapter: chapter, issues: &issues)
            validateQuestions(chapter.questions.trueFalse, label: "判断题", chapter: chapter, issues: &issues)
            validateQuestions(chapter.questions.shortAnswer, label: "简答题", chapter: chapter, issues: &issues)

            for point in chapter.knowledgePoints {
                let resources = point.resources ?? []
                let resourceIDs = resources.map(\.id)
                if Set(resourceIDs).count != resourceIDs.count {
                    issues.append("章节 \(chapter.id) 的知识点“\(point.title)”存在重复资源 ID")
                }
                for resource in resources where resource.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append("章节 \(chapter.id) 的知识点“\(point.title)”存在空资源 ID")
                }
                for resource in resources
                where resource.url.scheme?.lowercased() != "https" || resource.url.host?.isEmpty != false {
                    issues.append("资源“\(resource.title)”未使用 HTTPS 地址")
                }
            }
        }
        return issues
    }

    static func issues(in catalog: RemoteCourseCatalog) -> [String] {
        var issues: [String] = []
        var courseIDs = Set<String>()
        for course in catalog.courses {
            if course.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("在线目录存在空课程 ID")
            }
            if !courseIDs.insert(course.id).inserted {
                issues.append("在线目录课程 ID “\(course.id)”重复")
            }
            if course.courseURL.scheme?.lowercased() != "https" || course.courseURL.host?.isEmpty != false {
                issues.append("在线课程“\(course.title)”未使用 HTTPS 地址")
            }
        }
        return issues
    }

    private static func validateQuestions(
        _ questions: [Question],
        label: String,
        chapter: Chapter,
        issues: inout [String]
    ) {
        let ids = questions.map(\.id)
        if Set(ids).count != ids.count {
            issues.append("章节 \(chapter.id) 的\(label)存在重复题目 ID")
        }
        for question in questions where question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("章节 \(chapter.id) 的\(label) \(question.id) 缺少题干")
        }
    }
}
