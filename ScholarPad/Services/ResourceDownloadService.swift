import CryptoKit
import Foundation

actor ResourceDownloadService {
    private let maximumBytes: Int64 = 750 * 1024 * 1024

    func download(_ resource: LearningResource) async throws -> URL {
        guard resource.url.scheme?.lowercased() == "https", resource.url.host?.isEmpty == false else {
            throw ResourceDownloadError.insecureURL
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: resource.url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ResourceDownloadError.invalidServerResponse
        }
        guard response.url?.scheme?.lowercased() == "https", response.url?.host?.isEmpty == false else {
            throw ResourceDownloadError.insecureURL
        }

        let size = try fileSize(at: temporaryURL)
        guard size <= maximumBytes else {
            throw ResourceDownloadError.fileTooLarge
        }

        let directory = try resourceDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory
            .appendingPathComponent(fingerprint(resource.url.absoluteString))
            .appendingPathExtension(fileExtension(for: resource))

        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: target)
        return target
    }

    func remove(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func clearAll() throws {
        let directory = try resourceDirectory()
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func resourceDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ResourceDownloadError.cacheUnavailable
        }
        return applicationSupport
            .appendingPathComponent("ScholarPad", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
    }

    private func fingerprint(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .prefix(12)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func fileExtension(for resource: LearningResource) -> String {
        let candidate = resource.url.pathExtension.lowercased()
        let allowed = CharacterSet.alphanumerics
        if !candidate.isEmpty,
           candidate.count <= 8,
           candidate.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return candidate
        }
        switch resource.kind {
        case .video: "mp4"
        case .audio: "m4a"
        case .document: "pdf"
        case .image: "jpg"
        case .link: "html"
        }
    }
}

enum ResourceDownloadError: LocalizedError, Sendable {
    case insecureURL
    case invalidServerResponse
    case fileTooLarge
    case cacheUnavailable

    var errorDescription: String? {
        switch self {
        case .insecureURL: "离线资源必须使用 HTTPS 地址"
        case .invalidServerResponse: "资源服务器未返回有效文件"
        case .fileTooLarge: "单个资源不能超过 750 MB"
        case .cacheUnavailable: "无法访问离线资源目录"
        }
    }
}
