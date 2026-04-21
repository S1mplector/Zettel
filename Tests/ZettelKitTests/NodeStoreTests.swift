import AppKit
import XCTest
@testable import ZettelKit

@MainActor
final class NodeStoreTests: XCTestCase {
    func testCanCreateNestedNodes() {
        let store = NodeStore(fileURL: temporaryFileURL())

        let yearID = store.addRootNode(title: "2026")
        let topicID = store.addChildNode(to: yearID, title: "Swift")

        XCTAssertEqual(store.rootNodes.count, 1)
        XCTAssertEqual(store.node(with: yearID)?.title, "2026")
        XCTAssertEqual(store.node(with: topicID)?.title, "Swift")
    }

    func testDeleteRemovesNestedNode() {
        let store = NodeStore(fileURL: temporaryFileURL())

        let parentID = store.addRootNode(title: "Projects")
        let childID = store.addChildNode(to: parentID, title: "Zettel")

        store.deleteNode(with: childID)

        XCTAssertNil(store.node(with: childID))
        XCTAssertEqual(store.node(with: parentID)?.children.count, 0)
    }

    func testAddSiblingInsertsBesideExistingNode() {
        let store = NodeStore(fileURL: temporaryFileURL())
        let firstID = store.addRootNode(title: "2025")

        let secondID = store.addSiblingNode(after: firstID, title: "2026")

        XCTAssertEqual(store.rootNodes.map(\.title), ["2025", "2026"])
        XCTAssertEqual(store.rootNodes.last?.id, secondID)
    }

    func testIndentMovesNodeUnderPreviousSibling() {
        let store = NodeStore(fileURL: temporaryFileURL())
        _ = store.addRootNode(title: "2025")
        let topicID = store.addRootNode(title: "Swift")

        XCTAssertTrue(store.indentNode(topicID))

        XCTAssertEqual(store.rootNodes.count, 1)
        XCTAssertEqual(store.rootNodes[0].children.map(\.title), ["Swift"])
    }

    func testOutdentMovesNodeToParentLevel() {
        let store = NodeStore(fileURL: temporaryFileURL())
        let yearID = store.addRootNode(title: "2026")
        let topicID = store.addChildNode(to: yearID, title: "Swift")

        XCTAssertTrue(store.outdentNode(topicID))

        XCTAssertEqual(store.rootNodes.map(\.title), ["2026", "Swift"])
        XCTAssertTrue(store.node(with: yearID)?.children.isEmpty == true)
    }

    func testPreferredSelectionAfterDeletingUsesNearbyNode() {
        let store = NodeStore(fileURL: temporaryFileURL())
        let firstID = store.addRootNode(title: "First")
        let secondID = store.addRootNode(title: "Second")

        XCTAssertEqual(store.preferredSelectionAfterDeleting(firstID), secondID)
    }

    func testRichTextArchiveRoundTripsThroughPersistence() {
        let fileURL = temporaryFileURL()
        let store = NodeStore(fileURL: fileURL)
        let nodeID = store.addRootNode(title: "Research")
        let attributedString = NSMutableAttributedString(string: "Rich text")
        attributedString.append(NSAttributedString(attachment: NSTextAttachment()))

        let archived = AttributedTextArchive.encode(attributedString)
        store.updateContent(for: nodeID, content: archived)
        store.saveNow()

        let reloadedStore = NodeStore(fileURL: fileURL)
        let restored = AttributedTextArchive.decode(reloadedStore.node(with: nodeID)?.content)

        XCTAssertEqual(restored.string.count, attributedString.string.count)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("Store", isDirectory: true)
            .appendingPathComponent("store.json")
    }
}
