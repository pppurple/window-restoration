import Foundation

public struct RectSnapshot: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct DisplaySnapshot: Codable, Equatable, Sendable {
    public var uuid: String
    public var name: String
    public var bounds: RectSnapshot
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var scale: Double
    public var isBuiltIn: Bool

    public init(
        uuid: String,
        name: String,
        bounds: RectSnapshot,
        pixelWidth: Int,
        pixelHeight: Int,
        scale: Double,
        isBuiltIn: Bool
    ) {
        self.uuid = uuid
        self.name = name
        self.bounds = bounds
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
        self.isBuiltIn = isBuiltIn
    }
}

public struct DisplayConfiguration: Codable, Equatable, Sendable {
    public var identifier: String
    public var displays: [DisplaySnapshot]

    public init(displays: [DisplaySnapshot]) {
        self.displays = displays.sorted { $0.uuid < $1.uuid }
        identifier = Self.makeIdentifier(displays: self.displays)
    }

    public var summary: String {
        displays.map(\.name).joined(separator: " + ")
    }

    public static func makeIdentifier(displays: [DisplaySnapshot]) -> String {
        let canonical = displays
            .sorted { $0.uuid < $1.uuid }
            .map {
                [
                    $0.uuid,
                    String(format: "%.0f", $0.bounds.x),
                    String(format: "%.0f", $0.bounds.y),
                    String(format: "%.0f", $0.bounds.width),
                    String(format: "%.0f", $0.bounds.height),
                    String(format: "%.3f", $0.scale)
                ].joined(separator: ":")
            }
            .joined(separator: "|")

        // FNV-1a is used only to create a stable, filesystem-safe identifier.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in canonical.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}

public struct WindowSnapshot: Codable, Equatable, Sendable {
    public var bundleIdentifier: String
    public var applicationName: String
    public var title: String?
    public var accessibilityIdentifier: String?
    public var role: String?
    public var subrole: String?
    public var indexInApplication: Int
    public var frame: RectSnapshot

    public init(
        bundleIdentifier: String,
        applicationName: String,
        title: String?,
        accessibilityIdentifier: String?,
        role: String?,
        subrole: String?,
        indexInApplication: Int,
        frame: RectSnapshot
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.role = role
        self.subrole = subrole
        self.indexInApplication = indexInApplication
        self.frame = frame
    }
}

public struct LayoutProfile: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var displayConfiguration: DisplayConfiguration
    public var capturedAt: Date
    public var windows: [WindowSnapshot]

    public init(
        displayConfiguration: DisplayConfiguration,
        capturedAt: Date = Date(),
        windows: [WindowSnapshot]
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.displayConfiguration = displayConfiguration
        self.capturedAt = capturedAt
        self.windows = windows
    }
}

public struct RestoreReport: Equatable, Sendable {
    public var restored: Int
    public var skipped: Int
    public var failed: Int

    public init(restored: Int = 0, skipped: Int = 0, failed: Int = 0) {
        self.restored = restored
        self.skipped = skipped
        self.failed = failed
    }
}
