import Foundation

public struct ZettelNode: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var content: Data?
    public var children: [ZettelNode]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "Untitled Node",
        content: Data? = nil,
        children: [ZettelNode] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.children = children
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Node" : trimmed
    }

    public var outlineChildren: [ZettelNode]? {
        children.isEmpty ? nil : children
    }
}
