import Foundation
import XCTest
@testable import WindowRestorationCore

final class ProfileStoreTests: XCTestCase {
    func testProfileRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = DisplayConfiguration(displays: [
            DisplaySnapshot(
                uuid: "display",
                name: "Test Display",
                bounds: RectSnapshot(x: 0, y: 0, width: 1440, height: 900),
                pixelWidth: 2880,
                pixelHeight: 1800,
                scale: 2,
                isBuiltIn: true
            )
        ])
        let profile = LayoutProfile(
            displayConfiguration: configuration,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            windows: [makeWindow(title: "Document", index: 0)]
        )
        let store = ProfileStore(directory: directory)

        try store.save(profile)
        let loaded = try store.load(configurationID: configuration.identifier)

        XCTAssertEqual(loaded, profile)
    }

    func testMatcherPrefersExactTitleOverWindowOrder() {
        let stored = [
            makeWindow(title: "First", index: 0),
            makeWindow(title: "Second", index: 1)
        ]
        let current = [
            makeWindow(title: "Second", index: 0),
            makeWindow(title: "First", index: 1)
        ]

        let matches = WindowMatcher.match(stored: stored, current: current)

        XCTAssertEqual(matches[0].stored, 0)
        XCTAssertEqual(matches[0].current, 1)
        XCTAssertEqual(matches[1].stored, 1)
        XCTAssertEqual(matches[1].current, 0)
    }
}

private func makeWindow(title: String, index: Int) -> WindowSnapshot {
    WindowSnapshot(
        bundleIdentifier: "com.example.app",
        applicationName: "Example",
        title: title,
        accessibilityIdentifier: nil,
        role: "AXWindow",
        subrole: "AXStandardWindow",
        indexInApplication: index,
        frame: RectSnapshot(x: 10, y: 10, width: 800, height: 600)
    )
}
