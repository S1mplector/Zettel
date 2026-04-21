import Combine
import Foundation

@MainActor
public final class NodeStore: ObservableObject {
    @Published public private(set) var rootNodes: [ZettelNode]

    public let fileURL: URL

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let fileManager: FileManager
    private var pendingSaveWorkItem: DispatchWorkItem?

    public init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.rootNodes = []

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        load()
    }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        Self.applicationDirectoryURL(fileManager: fileManager)
            .appendingPathComponent("Store", isDirectory: true)
            .appendingPathComponent("store.json")
    }

    public func node(with id: UUID?) -> ZettelNode? {
        guard let id else {
            return nil
        }

        return Self.findNode(with: id, in: rootNodes)
    }

    public func allNodeIDs() -> [UUID] {
        Self.flatten(nodes: rootNodes).map(\.id)
    }

    public func titlePath(for id: UUID?) -> [String] {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes)
        else {
            return []
        }

        return Self.pathNodes(for: location.path, in: rootNodes).map(\.displayTitle)
    }

    @discardableResult
    public func addRootNode(title: String = "Untitled Node") -> UUID {
        let node = ZettelNode(title: title)
        rootNodes.append(node)
        scheduleSave()
        return node.id
    }

    @discardableResult
    public func addChildNode(to parentID: UUID?, title: String = "Untitled Node") -> UUID {
        guard let parentID else {
            return addRootNode(title: title)
        }

        let child = ZettelNode(title: title)
        if mutateNode(with: parentID, update: { node in
            node.children.append(child)
        }) {
            scheduleSave()
            return child.id
        }

        rootNodes.append(child)
        scheduleSave()
        return child.id
    }

    @discardableResult
    public func addSiblingNode(after id: UUID?, title: String = "Untitled Node") -> UUID {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes)
        else {
            return addRootNode(title: title)
        }

        let sibling = ZettelNode(title: title)
        Self.withNodeArray(at: location.parentPath, in: &rootNodes) { nodes in
            nodes.insert(sibling, at: location.index + 1)
        }

        touch(paths: [location.parentPath, location.parentPath + [location.index + 1]])
        scheduleSave()
        return sibling.id
    }

    public func updateTitle(for id: UUID, title: String) {
        guard mutateNode(with: id, update: { node in
            node.title = title
        }) else {
            return
        }

        scheduleSave()
    }

    public func updateContent(for id: UUID, content: Data?) {
        guard mutateNode(with: id, update: { node in
            node.content = content
        }) else {
            return
        }

        scheduleSave()
    }

    public func deleteNode(with id: UUID) {
        guard removeNode(with: id, from: &rootNodes) else {
            return
        }

        scheduleSave()
    }

    public func preferredSelectionAfterDeleting(_ id: UUID?) -> UUID? {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes)
        else {
            return allNodeIDs().first
        }

        let parentPath = location.parentPath
        let siblings = Self.nodesInContainer(at: parentPath, in: rootNodes)

        if location.index > 0 {
            return siblings[location.index - 1].id
        }

        if location.index + 1 < siblings.count {
            return siblings[location.index + 1].id
        }

        if let parent = Self.node(at: parentPath, in: rootNodes) {
            return parent.id
        }

        return rootNodes.count > 1 ? rootNodes[1].id : nil
    }

    public func canMoveNodeUp(_ id: UUID?) -> Bool {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes)
        else {
            return false
        }

        return location.index > 0
    }

    public func canMoveNodeDown(_ id: UUID?) -> Bool {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes)
        else {
            return false
        }

        let siblings = Self.nodesInContainer(at: location.parentPath, in: rootNodes)
        return location.index + 1 < siblings.count
    }

    public func canIndentNode(_ id: UUID?) -> Bool {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes)
        else {
            return false
        }

        return location.index > 0
    }

    public func canOutdentNode(_ id: UUID?) -> Bool {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes)
        else {
            return false
        }

        return location.path.count > 1
    }

    @discardableResult
    public func moveNodeUp(_ id: UUID?) -> Bool {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes),
            location.index > 0
        else {
            return false
        }

        Self.withNodeArray(at: location.parentPath, in: &rootNodes) { nodes in
            nodes.swapAt(location.index, location.index - 1)
        }

        touch(paths: [location.parentPath + [location.index - 1]])
        scheduleSave()
        return true
    }

    @discardableResult
    public func moveNodeDown(_ id: UUID?) -> Bool {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes)
        else {
            return false
        }

        let siblings = Self.nodesInContainer(at: location.parentPath, in: rootNodes)
        guard location.index + 1 < siblings.count else {
            return false
        }

        Self.withNodeArray(at: location.parentPath, in: &rootNodes) { nodes in
            nodes.swapAt(location.index, location.index + 1)
        }

        touch(paths: [location.parentPath + [location.index + 1]])
        scheduleSave()
        return true
    }

    @discardableResult
    public func indentNode(_ id: UUID?) -> Bool {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes),
            location.index > 0
        else {
            return false
        }

        var newPath: [Int]?

        Self.withNodeArray(at: location.parentPath, in: &rootNodes) { nodes in
            var movedNode = nodes.remove(at: location.index)
            movedNode.updatedAt = .now
            nodes[location.index - 1].children.append(movedNode)
            newPath = location.parentPath + [location.index - 1, nodes[location.index - 1].children.count - 1]
        }

        if let newPath {
            touch(paths: [location.parentPath, newPath])
        }

        scheduleSave()
        return true
    }

    @discardableResult
    public func outdentNode(_ id: UUID?) -> Bool {
        guard
            let id,
            let location = Self.location(of: id, in: rootNodes),
            location.path.count > 1
        else {
            return false
        }

        let parentPath = location.parentPath
        let grandParentPath = Array(parentPath.dropLast())
        let insertionIndex = parentPath.last.map { $0 + 1 } ?? 0
        var movedNode: ZettelNode?

        Self.withNodeArray(at: parentPath, in: &rootNodes) { nodes in
            movedNode = nodes.remove(at: location.index)
        }

        guard var movedNode else {
            return false
        }

        movedNode.updatedAt = .now
        Self.withNodeArray(at: grandParentPath, in: &rootNodes) { nodes in
            nodes.insert(movedNode, at: insertionIndex)
        }

        touch(paths: [parentPath, grandParentPath + [insertionIndex]])
        scheduleSave()
        return true
    }

    public func saveNow() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil

        do {
            try persist(nodes: rootNodes)
        } catch {
            NSLog("Zettel failed to save nodes: \(error.localizedDescription)")
        }
    }

    private var storeDirectoryURL: URL {
        fileURL.deletingLastPathComponent()
    }

    private var manifestFileName: String {
        fileURL.lastPathComponent
    }

    private var applicationDirectoryURL: URL {
        storeDirectoryURL.deletingLastPathComponent()
    }

    private var stagingDirectoryURL: URL {
        applicationDirectoryURL.appendingPathComponent("Store.staging", isDirectory: true)
    }

    private var backupDirectoryURL: URL {
        applicationDirectoryURL.appendingPathComponent("Store.backup", isDirectory: true)
    }

    private func load() {
        do {
            if fileManager.fileExists(atPath: storeDirectoryURL.path) {
                rootNodes = try loadSnapshot(from: storeDirectoryURL)
                return
            }
        } catch {
            NSLog("Zettel failed to load primary store: \(error.localizedDescription)")
        }

        do {
            if fileManager.fileExists(atPath: backupDirectoryURL.path) {
                let recoveredNodes = try loadSnapshot(from: backupDirectoryURL)
                rootNodes = recoveredNodes
                try? persist(nodes: recoveredNodes)
                return
            }
        } catch {
            NSLog("Zettel failed to load backup store: \(error.localizedDescription)")
        }

        if let legacyNodes = loadLegacyNodes() {
            rootNodes = legacyNodes
            saveNow()
            return
        }

        rootNodes = []
    }

    private func loadLegacyNodes() -> [ZettelNode]? {
        let legacyURL = Self.legacyFileURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: legacyURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: legacyURL)
            return try decoder.decode([ZettelNode].self, from: data)
        } catch {
            NSLog("Zettel failed to migrate legacy storage: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadSnapshot(from directoryURL: URL) throws -> [ZettelNode] {
        let manifestURL = directoryURL.appendingPathComponent(manifestFileName)
        let contentDirectoryURL = directoryURL.appendingPathComponent("Content", isDirectory: true)
        let data = try Data(contentsOf: manifestURL)
        let snapshot = try decoder.decode(PersistedStoreSnapshot.self, from: data)

        guard snapshot.schemaVersion == PersistedStoreSnapshot.currentSchemaVersion else {
            throw StorageError.unsupportedSchema(snapshot.schemaVersion)
        }

        return try snapshot.rootNodes.map { try hydrateNode($0, contentDirectoryURL: contentDirectoryURL) }
    }

    private func persist(nodes: [ZettelNode]) throws {
        try fileManager.createDirectory(
            at: applicationDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        if fileManager.fileExists(atPath: stagingDirectoryURL.path) {
            try fileManager.removeItem(at: stagingDirectoryURL)
        }

        try fileManager.createDirectory(
            at: stagingDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let contentDirectoryURL = stagingDirectoryURL.appendingPathComponent("Content", isDirectory: true)
        try fileManager.createDirectory(
            at: contentDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        for contentFile in Self.contentFiles(from: nodes) {
            let targetURL = contentDirectoryURL.appendingPathComponent(contentFile.fileName)
            try contentFile.data.write(to: targetURL, options: [.atomic])
        }

        let snapshot = PersistedStoreSnapshot(
            schemaVersion: PersistedStoreSnapshot.currentSchemaVersion,
            savedAt: .now,
            rootNodes: Self.persistedNodes(from: nodes)
        )

        let manifestURL = stagingDirectoryURL.appendingPathComponent(manifestFileName)
        let manifestData = try encoder.encode(snapshot)
        try manifestData.write(to: manifestURL, options: [.atomic])

        if fileManager.fileExists(atPath: backupDirectoryURL.path) {
            try? fileManager.removeItem(at: backupDirectoryURL)
        }

        if fileManager.fileExists(atPath: storeDirectoryURL.path) {
            _ = try fileManager.replaceItemAt(
                storeDirectoryURL,
                withItemAt: stagingDirectoryURL,
                backupItemName: backupDirectoryURL.lastPathComponent,
                options: [.usingNewMetadataOnly]
            )
        } else {
            try fileManager.moveItem(at: stagingDirectoryURL, to: storeDirectoryURL)
        }
    }

    private func hydrateNode(
        _ persistedNode: PersistedNode,
        contentDirectoryURL: URL
    ) throws -> ZettelNode {
        let contentData = try persistedNode.contentFileName.map { fileName in
            let contentURL = contentDirectoryURL.appendingPathComponent(fileName)
            return try Data(contentsOf: contentURL)
        }

        return ZettelNode(
            id: persistedNode.id,
            title: persistedNode.title,
            content: contentData,
            children: try persistedNode.children.map { child in
                try hydrateNode(child, contentDirectoryURL: contentDirectoryURL)
            },
            createdAt: persistedNode.createdAt,
            updatedAt: persistedNode.updatedAt
        )
    }

    private func scheduleSave() {
        pendingSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }

        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func mutateNode(with id: UUID, update: (inout ZettelNode) -> Void) -> Bool {
        Self.mutateNode(with: id, in: &rootNodes, update: update)
    }

    private func touch(paths: [[Int]]) {
        let now = Date.now
        var visited = Set<[Int]>()

        for path in paths {
            guard !path.isEmpty else {
                continue
            }

            for depth in 1...path.count {
                let prefix = Array(path.prefix(depth))
                guard visited.insert(prefix).inserted else {
                    continue
                }

                Self.withNode(at: prefix, in: &rootNodes) { node in
                    node.updatedAt = now
                }
            }
        }
    }

    private static func applicationDirectoryURL(fileManager: FileManager) -> URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return applicationSupportURL.appendingPathComponent("Zettel", isDirectory: true)
    }

    private static func legacyFileURL(fileManager: FileManager) -> URL {
        applicationDirectoryURL(fileManager: fileManager)
            .appendingPathComponent("nodes.json")
    }

    private static func contentFiles(from nodes: [ZettelNode]) -> [PersistedContentFile] {
        nodes.flatMap { node in
            let ownContent = node.content.map {
                PersistedContentFile(
                    fileName: contentFileName(for: node.id),
                    data: $0
                )
            }

            return (ownContent.map { [$0] } ?? []) + contentFiles(from: node.children)
        }
    }

    private static func persistedNodes(from nodes: [ZettelNode]) -> [PersistedNode] {
        nodes.map { node in
            PersistedNode(
                id: node.id,
                title: node.title,
                contentFileName: node.content == nil ? nil : contentFileName(for: node.id),
                children: persistedNodes(from: node.children),
                createdAt: node.createdAt,
                updatedAt: node.updatedAt
            )
        }
    }

    private static func contentFileName(for id: UUID) -> String {
        "\(id.uuidString).rtfd"
    }

    private static func findNode(with id: UUID, in nodes: [ZettelNode]) -> ZettelNode? {
        for node in nodes {
            if node.id == id {
                return node
            }

            if let child = findNode(with: id, in: node.children) {
                return child
            }
        }

        return nil
    }

    private static func flatten(nodes: [ZettelNode]) -> [ZettelNode] {
        nodes.flatMap { node in
            [node] + flatten(nodes: node.children)
        }
    }

    private static func location(
        of id: UUID,
        in nodes: [ZettelNode],
        path: [Int] = []
    ) -> NodeLocation? {
        for index in nodes.indices {
            let nextPath = path + [index]

            if nodes[index].id == id {
                return NodeLocation(path: nextPath)
            }

            if let childLocation = location(of: id, in: nodes[index].children, path: nextPath) {
                return childLocation
            }
        }

        return nil
    }

    private static func node(at path: [Int], in tree: [ZettelNode]) -> ZettelNode? {
        guard let firstIndex = path.first, tree.indices.contains(firstIndex) else {
            return nil
        }

        let currentNode = tree[firstIndex]
        guard path.count > 1 else {
            return currentNode
        }

        return node(at: Array(path.dropFirst()), in: currentNode.children)
    }

    private static func nodesInContainer(at path: [Int], in tree: [ZettelNode]) -> [ZettelNode] {
        guard let firstIndex = path.first else {
            return tree
        }

        guard tree.indices.contains(firstIndex) else {
            return []
        }

        return nodesInContainer(at: Array(path.dropFirst()), in: tree[firstIndex].children)
    }

    private static func pathNodes(for path: [Int], in tree: [ZettelNode]) -> [ZettelNode] {
        guard let firstIndex = path.first, tree.indices.contains(firstIndex) else {
            return []
        }

        let currentNode = tree[firstIndex]
        return [currentNode] + pathNodes(for: Array(path.dropFirst()), in: currentNode.children)
    }

    private static func withNodeArray<Result>(
        at path: [Int],
        in nodes: inout [ZettelNode],
        _ body: (inout [ZettelNode]) -> Result
    ) -> Result {
        guard let firstIndex = path.first else {
            return body(&nodes)
        }

        return withNodeArray(at: Array(path.dropFirst()), in: &nodes[firstIndex].children, body)
    }

    private static func withNode(
        at path: [Int],
        in nodes: inout [ZettelNode],
        _ body: (inout ZettelNode) -> Void
    ) {
        guard let firstIndex = path.first else {
            return
        }

        if path.count == 1 {
            body(&nodes[firstIndex])
            return
        }

        withNode(at: Array(path.dropFirst()), in: &nodes[firstIndex].children, body)
    }

    private static func mutateNode(
        with id: UUID,
        in nodes: inout [ZettelNode],
        update: (inout ZettelNode) -> Void
    ) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == id {
                update(&nodes[index])
                nodes[index].updatedAt = .now
                return true
            }

            if mutateNode(with: id, in: &nodes[index].children, update: update) {
                nodes[index].updatedAt = .now
                return true
            }
        }

        return false
    }

    private func removeNode(with id: UUID, from nodes: inout [ZettelNode]) -> Bool {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes.remove(at: index)
            return true
        }

        for index in nodes.indices {
            if removeNode(with: id, from: &nodes[index].children) {
                nodes[index].updatedAt = .now
                return true
            }
        }

        return false
    }

    private struct NodeLocation {
        let path: [Int]

        var parentPath: [Int] {
            Array(path.dropLast())
        }

        var index: Int {
            path.last ?? 0
        }
    }

    private struct PersistedStoreSnapshot: Codable {
        static let currentSchemaVersion = 2

        let schemaVersion: Int
        let savedAt: Date
        let rootNodes: [PersistedNode]
    }

    private struct PersistedNode: Codable {
        let id: UUID
        let title: String
        let contentFileName: String?
        let children: [PersistedNode]
        let createdAt: Date
        let updatedAt: Date
    }

    private struct PersistedContentFile {
        let fileName: String
        let data: Data
    }

    private enum StorageError: LocalizedError {
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedSchema(let version):
                return "Unsupported storage schema version \(version)."
            }
        }
    }
}
