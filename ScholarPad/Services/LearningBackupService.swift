import Foundation

actor LearningBackupService {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func encode(_ backup: LearningBackup) throws -> Data {
        try encoder.encode(backup)
    }

    func decode(from url: URL) throws -> LearningBackup {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) <= 20 * 1024 * 1024 else {
            throw LearningBackupError.fileTooLarge
        }
        let backup = try decoder.decode(LearningBackup.self, from: Data(contentsOf: url))
        guard backup.version == 1 else {
            throw LearningBackupError.unsupportedVersion
        }
        return backup
    }
}

enum LearningBackupError: LocalizedError, Sendable {
    case fileTooLarge
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .fileTooLarge: "学习备份不能超过 20 MB"
        case .unsupportedVersion: "该学习备份版本暂不受支持"
        }
    }
}

