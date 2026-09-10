import Foundation

public enum ProfileStoreError: LocalizedError {
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "未対応の保存形式です（version \(version)）。"
        }
    }
}

public struct ProfileStore: Sendable {
    public let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.directory = applicationSupport
                .appendingPathComponent("WindowRestoration", isDirectory: true)
                .appendingPathComponent("profiles", isDirectory: true)
        }
    }

    public func save(_ profile: LayoutProfile) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(profile)
        try data.write(to: fileURL(for: profile.displayConfiguration.identifier), options: .atomic)
    }

    public func load(configurationID: String) throws -> LayoutProfile? {
        let url = fileURL(for: configurationID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try decodeProfile(at: url)
    }

    public func loadAll() throws -> [LayoutProfile] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decodeProfile(at: $0) }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    public func hasProfile(configurationID: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: configurationID).path)
    }

    private func fileURL(for configurationID: String) -> URL {
        directory.appendingPathComponent("\(configurationID).json", isDirectory: false)
    }

    private func decodeProfile(at url: URL) throws -> LayoutProfile {
        let profile = try Self.decoder.decode(LayoutProfile.self, from: Data(contentsOf: url))
        guard profile.schemaVersion == LayoutProfile.currentSchemaVersion else {
            throw ProfileStoreError.unsupportedSchema(profile.schemaVersion)
        }
        return profile
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
