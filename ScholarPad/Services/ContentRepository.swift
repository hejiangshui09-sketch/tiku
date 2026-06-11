import CryptoKit
import Foundation

actor ContentRepository {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
    }

    func loadBundledCourse() throws -> Course {
        guard let url = Bundle.main.url(forResource: "chapters", withExtension: "json") else {
            throw ContentError.missingBundledContent
        }
        let data = try Data(contentsOf: url)
        return try makeCourse(
            from: data,
            id: "core-course",
            title: "系统化精品课程",
            subtitle: "从知识理解到题目掌握的完整学习路径",
            subject: "核心课程",
            accent: .indigo,
            source: .bundled
        )
    }

    func loadImportedCourse(from url: URL) throws -> Course {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) <= 50 * 1024 * 1024 else {
            throw ContentError.payloadTooLarge
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let baseName = url.deletingPathExtension().lastPathComponent
        return try makeCourse(
            from: data,
            id: "import-\(fingerprint(url.absoluteString))",
            title: baseName,
            subtitle: "本地导入课程",
            subject: "自定义课程",
            accent: .cyan,
            source: .imported
        )
    }

    func loadRemoteCourse(from url: URL) async throws -> Course {
        let data = try await fetchJSON(from: url)
        return try makeCourse(
            from: data,
            id: "remote-\(fingerprint(url.absoluteString))",
            title: url.deletingPathExtension().lastPathComponent,
            subtitle: "在线同步课程",
            subject: "云端课程",
            accent: .violet,
            source: .remote(url)
        )
    }

    func loadRemoteCourse(_ descriptor: RemoteCourseDescriptor) async throws -> Course {
        let data = try await fetchJSON(from: descriptor.courseURL)
        var course = try makeCourse(
            from: data,
            id: "course-\(fingerprint(descriptor.id))",
            title: descriptor.title,
            subtitle: descriptor.subtitle,
            subject: descriptor.subject,
            accent: descriptor.accent,
            source: .remote(descriptor.courseURL)
        )
        course.catalogID = descriptor.id
        return course
    }

    func loadRemoteCatalog(from url: URL) async throws -> RemoteCourseCatalog {
        let data = try await fetchJSON(from: url)
        do {
            let catalog = try decoder.decode(RemoteCourseCatalog.self, from: data)
            let issues = CourseValidator.issues(in: catalog)
            guard issues.isEmpty else {
                throw ContentError.invalidCourse(issues)
            }
            return catalog
        } catch let error as ContentError {
            throw error
        } catch {
            throw ContentError.decodingFailed(error.localizedDescription)
        }
    }

    func loadCachedCatalog() throws -> RemoteCourseCatalog? {
        let url = try catalogCacheURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let catalog = try decoder.decode(RemoteCourseCatalog.self, from: Data(contentsOf: url))
        guard CourseValidator.issues(in: catalog).isEmpty else { return nil }
        return catalog
    }

    func storeCachedCatalog(_ catalog: RemoteCourseCatalog) throws {
        let url = try catalogCacheURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(catalog).write(to: url, options: .atomic)
    }

    private func fetchJSON(from url: URL) async throws -> Data {
        guard url.scheme?.lowercased() == "https", url.host?.isEmpty == false else {
            throw ContentError.insecureURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadRevalidatingCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ContentError.invalidServerResponse
        }
        guard response.url?.scheme?.lowercased() == "https", response.url?.host?.isEmpty == false else {
            throw ContentError.insecureURL
        }
        guard data.count <= 50 * 1024 * 1024 else {
            throw ContentError.payloadTooLarge
        }
        return data
    }

    func loadCachedCourses() throws -> [Course] {
        let directory = try cacheDirectory()
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }

        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let record = try? decoder.decode(CachedCourseRecord.self, from: data),
                  CourseValidator.issues(in: record.payload).isEmpty else {
                return nil
            }
            return record.course
        }
    }

    func storeCachedCourse(_ course: Course) throws {
        guard !course.source.isBundled else { return }
        let directory = try cacheDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(CachedCourseRecord(course))
        try data.write(to: cachedCourseURL(id: course.id, directory: directory), options: .atomic)
    }

    func deleteCachedCourse(id: String) throws {
        let directory = try cacheDirectory()
        let url = cachedCourseURL(id: id, directory: directory)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func makeCourse(
        from data: Data,
        id: String,
        title: String,
        subtitle: String,
        subject: String,
        accent: CourseAccent,
        source: CourseSource
    ) throws -> Course {
        do {
            let payload = try decoder.decode(CoursePayload.self, from: data)
            guard !payload.chapters.isEmpty else {
                throw ContentError.emptyCourse
            }
            let issues = CourseValidator.issues(in: payload)
            guard issues.isEmpty else {
                throw ContentError.invalidCourse(issues)
            }
            let resolvedID = nonempty(payload.courseID)
                .map { "course-\(fingerprint($0))" }
                ?? id
            return Course(
                id: resolvedID,
                title: nonempty(payload.courseTitle) ?? title,
                subtitle: nonempty(payload.courseSubtitle) ?? subtitle,
                subject: nonempty(payload.courseSubject) ?? subject,
                accent: payload.courseAccent ?? accent,
                payload: payload,
                source: source
            )
        } catch let error as ContentError {
            throw error
        } catch {
            throw ContentError.decodingFailed(error.localizedDescription)
        }
    }

    private func fingerprint(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .prefix(12)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private func cacheDirectory() throws -> URL {
        try applicationDirectory().appendingPathComponent("Courses", isDirectory: true)
    }

    private func catalogCacheURL() throws -> URL {
        try applicationDirectory().appendingPathComponent("catalog.json")
    }

    private func applicationDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ContentError.cacheUnavailable
        }
        return applicationSupport
            .appendingPathComponent("ScholarPad", isDirectory: true)
    }

    private func cachedCourseURL(id: String, directory: URL) -> URL {
        directory.appendingPathComponent(fingerprint(id)).appendingPathExtension("json")
    }
}

enum ContentError: LocalizedError, Sendable {
    case missingBundledContent
    case invalidServerResponse
    case emptyCourse
    case decodingFailed(String)
    case cacheUnavailable
    case insecureURL
    case payloadTooLarge
    case invalidCourse([String])

    var errorDescription: String? {
        switch self {
        case .missingBundledContent:
            "应用内未找到 chapters.json"
        case .invalidServerResponse:
            "服务器未返回有效课程数据"
        case .emptyCourse:
            "课程文件中没有章节"
        case .decodingFailed(let reason):
            "课程 JSON 格式不兼容：\(reason)"
        case .cacheUnavailable:
            "无法访问应用课程缓存目录"
        case .insecureURL:
            "在线课程与目录必须使用 HTTPS 地址"
        case .payloadTooLarge:
            "课程 JSON 不能超过 50 MB，请将大型媒体改为资源链接"
        case .invalidCourse(let issues):
            "课程内容存在问题：\(issues.prefix(3).joined(separator: "；"))"
        }
    }
}

private struct CachedCourseRecord: Codable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let subject: String
    let accent: CourseAccent
    let payload: CoursePayload
    let sourceKind: String
    let sourceURL: URL?
    let catalogID: String?

    init(_ course: Course) {
        id = course.id
        title = course.title
        subtitle = course.subtitle
        subject = course.subject
        accent = course.accent
        payload = course.payload
        catalogID = course.catalogID
        switch course.source {
        case .bundled:
            sourceKind = "bundled"
            sourceURL = nil
        case .imported:
            sourceKind = "imported"
            sourceURL = nil
        case .remote(let url):
            sourceKind = "remote"
            sourceURL = url
        }
    }

    var course: Course {
        let source: CourseSource
        if sourceKind == "remote", let sourceURL {
            source = .remote(sourceURL)
        } else {
            source = .imported
        }
        return Course(
            id: id,
            title: title,
            subtitle: subtitle,
            subject: subject,
            accent: accent,
            payload: payload,
            source: source,
            catalogID: catalogID
        )
    }
}
