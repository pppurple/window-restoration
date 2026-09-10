import AppKit
import CoreGraphics
import Foundation

public enum DisplayProviderError: LocalizedError {
    case unableToReadDisplays(CGError)
    case noDisplays

    public var errorDescription: String? {
        switch self {
        case .unableToReadDisplays(let error):
            "ディスプレイ情報を取得できませんでした（\(error.rawValue)）。"
        case .noDisplays:
            "有効なディスプレイが見つかりませんでした。"
        }
    }
}

@MainActor
public struct DisplayProvider {
    public init() {}

    public func currentConfiguration() throws -> DisplayConfiguration {
        var count: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &count)
        guard result == .success else {
            throw DisplayProviderError.unableToReadDisplays(result)
        }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(count))
        result = CGGetActiveDisplayList(count, &displayIDs, &count)
        guard result == .success else {
            throw DisplayProviderError.unableToReadDisplays(result)
        }

        let screensByID: [CGDirectDisplayID: NSScreen] = Dictionary(
            uniqueKeysWithValues: NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return (CGDirectDisplayID(number.uint32Value), screen)
            }
        )

        let displays = displayIDs.prefix(Int(count)).map { displayID in
            let bounds = CGDisplayBounds(displayID)
            let screen = screensByID[displayID]
            return DisplaySnapshot(
                uuid: displayUUID(displayID),
                name: screen?.localizedName ?? "Display \(displayID)",
                bounds: RectSnapshot(
                    x: bounds.origin.x,
                    y: bounds.origin.y,
                    width: bounds.width,
                    height: bounds.height
                ),
                pixelWidth: CGDisplayPixelsWide(displayID),
                pixelHeight: CGDisplayPixelsHigh(displayID),
                scale: Double(screen?.backingScaleFactor ?? 1),
                isBuiltIn: CGDisplayIsBuiltin(displayID) != 0
            )
        }

        guard !displays.isEmpty else {
            throw DisplayProviderError.noDisplays
        }
        return DisplayConfiguration(displays: displays)
    }

    private func displayUUID(_ displayID: CGDirectDisplayID) -> String {
        guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return "display-\(displayID)"
        }
        let uuid = unmanagedUUID.takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }
}
