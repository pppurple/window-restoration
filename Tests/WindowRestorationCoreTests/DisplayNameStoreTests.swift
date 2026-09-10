import Foundation
import XCTest
@testable import WindowRestorationCore

final class DisplayNameStoreTests: XCTestCase {
    func testNamesRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = DisplayNameStore(
            fileURL: directory.appendingPathComponent("display-names.json")
        )
        let names = [
            "display-a": "自宅モニター",
            "display-b": "会社24インチモニター"
        ]

        try store.save(names)

        XCTAssertEqual(try store.load(), names)
    }

    func testMissingFileReturnsEmptyNames() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        XCTAssertEqual(try DisplayNameStore(fileURL: fileURL).load(), [:])
    }
}
