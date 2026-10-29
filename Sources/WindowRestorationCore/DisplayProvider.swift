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
        let screensByID: [CGDirectDisplayID: NSScreen] = Dictionary(
            uniqueKeysWithValues: NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                    return nil
                }
                return (CGDirectDisplayID(number.uint32Value), screen)
            }
        )

        // Asking Core Graphics for the count with maxDisplays == 0 can
        // temporarily return zero during display reconfiguration on recent
        // macOS versions. Read into a sufficiently large buffer in one call.
        var displayBuffer = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        let result = CGGetActiveDisplayList(
            UInt32(displayBuffer.count),
            &displayBuffer,
            &count
        )

        let displayIDs: [CGDirectDisplayID]
        if result == .success, count > 0 {
            displayIDs = Array(displayBuffer.prefix(Int(count)))
        } else if !screensByID.isEmpty {
            // NSScreen already represents the displays available to AppKit and
            // is a safe fallback while Core Graphics is between states.
            displayIDs = Array(screensByID.keys)
        } else if result != .success {
            throw DisplayProviderError.unableToReadDisplays(result)
        } else {
            throw DisplayProviderError.noDisplays
        }

        let displays = displayIDs.map { displayID in
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
