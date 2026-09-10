import AppKit
import ApplicationServices
import Foundation

@MainActor
public final class AccessibilityWindowService {
    private struct LiveWindow {
        var snapshot: WindowSnapshot
        var element: AXUIElement
    }

    public init() {}

    public var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public func captureWindows() -> [WindowSnapshot] {
        liveWindows().map(\.snapshot)
    }

    public func restore(_ profile: LayoutProfile) -> RestoreReport {
        let current = liveWindows()
        let currentSnapshots = current.map(\.snapshot)
        let matches = WindowMatcher.match(stored: profile.windows, current: currentSnapshots)
        var report = RestoreReport(
            restored: 0,
            skipped: profile.windows.count - matches.count,
            failed: 0
        )

        for match in matches {
            let target = profile.windows[match.stored].frame
            let element = current[match.current].element
            if setFrame(target, on: element) {
                report.restored += 1
            } else {
                report.failed += 1
            }
        }
        return report
    }

    private func liveWindows() -> [LiveWindow] {
        NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .flatMap(windows(for:))
    }

    private func windows(for application: NSRunningApplication) -> [LiveWindow] {
        guard let bundleIdentifier = application.bundleIdentifier else { return [] }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let elements: [AXUIElement] = attribute(kAXWindowsAttribute, from: appElement) else {
            return []
        }

        return elements.enumerated().compactMap { index, element in
            guard
                let position = pointAttribute(kAXPositionAttribute, from: element),
                let size = sizeAttribute(kAXSizeAttribute, from: element),
                size.width > 0,
                size.height > 0
            else {
                return nil
            }

            let role: String? = attribute(kAXRoleAttribute, from: element)
            guard role == nil || role == kAXWindowRole else { return nil }

            return LiveWindow(
                snapshot: WindowSnapshot(
                    bundleIdentifier: bundleIdentifier,
                    applicationName: application.localizedName ?? bundleIdentifier,
                    title: attribute(kAXTitleAttribute, from: element),
                    accessibilityIdentifier: attribute(kAXIdentifierAttribute, from: element),
                    role: role,
                    subrole: attribute(kAXSubroleAttribute, from: element),
                    indexInApplication: index,
                    frame: RectSnapshot(
                        x: position.x,
                        y: position.y,
                        width: size.width,
                        height: size.height
                    )
                ),
                element: element
            )
        }
    }

    private func setFrame(_ frame: RectSnapshot, on element: AXUIElement) -> Bool {
        var point = CGPoint(x: frame.x, y: frame.y)
        var size = CGSize(width: frame.width, height: frame.height)
        guard
            let positionValue = AXValueCreate(.cgPoint, &point),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            return false
        }

        // Size first: some apps clamp the position using the current window size.
        let sizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        let positionResult = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        return sizeResult == .success && positionResult == .success
    }

    private func attribute<T>(_ name: String, from element: AXUIElement) -> T? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &rawValue) == .success else {
            return nil
        }
        return rawValue as? T
    }

    private func pointAttribute(_ name: String, from element: AXUIElement) -> CGPoint? {
        guard let value: AXValue = attribute(name, from: element), AXValueGetType(value) == .cgPoint else {
            return nil
        }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(_ name: String, from element: AXUIElement) -> CGSize? {
        guard let value: AXValue = attribute(name, from: element), AXValueGetType(value) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }
}
