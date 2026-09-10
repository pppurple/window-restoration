import XCTest
@testable import WindowRestorationCore

final class DisplayConfigurationTests: XCTestCase {
    func testConfigurationIdentifierIsIndependentOfDisplayOrder() {
        let first = makeDisplay(uuid: "A", x: 0)
        let second = makeDisplay(uuid: "B", x: 1440)

        XCTAssertEqual(
            DisplayConfiguration(displays: [first, second]).identifier,
            DisplayConfiguration(displays: [second, first]).identifier
        )
    }

    func testConfigurationIdentifierChangesWithArrangement() {
        let display = makeDisplay(uuid: "A", x: 0)
        let moved = makeDisplay(uuid: "A", x: 100)

        XCTAssertNotEqual(
            DisplayConfiguration(displays: [display]).identifier,
            DisplayConfiguration(displays: [moved]).identifier
        )
    }
}

private func makeDisplay(uuid: String, x: Double) -> DisplaySnapshot {
    DisplaySnapshot(
        uuid: uuid,
        name: uuid,
        bounds: RectSnapshot(x: x, y: 0, width: 1440, height: 900),
        pixelWidth: 2880,
        pixelHeight: 1800,
        scale: 2,
        isBuiltIn: true
    )
}
