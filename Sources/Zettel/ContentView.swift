import SwiftUI
import ZettelKit

struct ContentView: View {
    @ObservedObject var store: NodeStore

    @AppStorage(AppSettingKey.sidebarDensity) private var sidebarDensityRawValue = SidebarDensity.comfortable.rawValue
    @AppStorage(AppSettingKey.showSidebarChildCounts) private var showSidebarChildCounts = true
    @AppStorage(AppSettingKey.showTreeGuides) private var showTreeGuides = true
    @AppStorage(AppSettingKey.showNodeMetadata) private var showNodeMetadata = true
    @AppStorage(AppSettingKey.autoExpandSelectionPath) private var autoExpandSelectionPath = true

    @State private var selection: UUID?
    @State private var expandedNodeIDs: Set<UUID> = []

    private var selectedNode: ZettelNode? {
        store.node(with: selection)
    }

    private var sidebarDensity: SidebarDensity {
        SidebarDensity(rawValue: sidebarDensityRawValue) ?? .comfortable
    }

    private var canCreateSibling: Bool {
        selection != nil
    }

    private var canMoveUp: Bool {
        store.canMoveNodeUp(selection)
    }

    private var canMoveDown: Bool {
        store.canMoveNodeDown(selection)
    }

    private var canIndent: Bool {
        store.canIndentNode(selection)
    }

    private var canOutdent: Bool {
        store.canOutdentNode(selection)
    }

    var body: some View {
        NavigationSplitView {
            TreeSidebarView(
                nodes: store.rootNodes,
                selection: $selection,
                expandedNodeIDs: $expandedNodeIDs,
                density: sidebarDensity,
                showChildCounts: showSidebarChildCounts,
                showGuides: showTreeGuides,
                totalNodeCount: store.allNodeIDs().count,
                selectedPath: store.titlePath(for: selection),
                onCreateRoot: addRootNode,
                onOpenSettings: AppWindowController.openSettings,
                onAddChild: addChildNode,
                onAddSibling: addSiblingNode,
                onMoveUp: moveNodeUp,
                onMoveDown: moveNodeDown,
                onIndent: indentNode,
                onOutdent: outdentNode,
                onDelete: delete,
                canMoveUp: store.canMoveNodeUp,
                canMoveDown: store.canMoveNodeDown,
                canIndent: store.canIndentNode,
                canOutdent: store.canOutdentNode
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            if let selectedNode {
                NodeDetailView(
                    node: selectedNode,
                    titlePath: store.titlePath(for: selectedNode.id),
                    showMetadata: showNodeMetadata,
                    onTitleChange: { store.updateTitle(for: selectedNode.id, title: $0) },
                    onContentChange: { store.updateContent(for: selectedNode.id, content: $0) }
                )
            } else {
                ContentUnavailableView(
                    "Select a Node",
                    systemImage: "square.and.pencil",
                    description: Text("Each node can hold rich text and pasted images.")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: addRootNode) {
                    Label("New Root Node", systemImage: "plus")
                }
                .keyboardShortcut("n")

                Button {
                    addChildNode(selection)
                } label: {
                    Label("New Child Node", systemImage: "plus.square.on.square")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button {
                    addSiblingNode(selection)
                } label: {
                    Label("New Sibling Node", systemImage: "plus.rectangle.on.rectangle")
                }
                .disabled(!canCreateSibling)
                .keyboardShortcut("n", modifiers: [.command, .option])

                Menu {
                    Button("Move Up") {
                        moveNodeUp(selection)
                    }
                    .disabled(!canMoveUp)

                    Button("Move Down") {
                        moveNodeDown(selection)
                    }
                    .disabled(!canMoveDown)

                    Divider()

                    Button("Indent") {
                        indentNode(selection)
                    }
                    .disabled(!canIndent)

                    Button("Outdent") {
                        outdentNode(selection)
                    }
                    .disabled(!canOutdent)
                } label: {
                    Label("Organize Nodes", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                }
                .disabled(selection == nil)

                Button(role: .destructive) {
                    delete(selection)
                } label: {
                    Label("Delete Node", systemImage: "trash")
                }
                .disabled(selection == nil)
                .keyboardShortcut(.delete, modifiers: [.command])
            }
        }
        .onAppear {
            seedExpandedNodesIfNeeded()

            if selection == nil {
                selection = store.allNodeIDs().first
            }

            revealSelectionIfNeeded()
        }
        .onChange(of: selection) { _, _ in
            revealSelectionIfNeeded()
        }
        .onChange(of: store.allNodeIDs()) { _, nodeIDs in
            expandedNodeIDs.formIntersection(Set(nodeIDs))
            seedExpandedNodesIfNeeded()
            revealSelectionIfNeeded()
        }
    }

    private func addRootNode() {
        selection = store.addRootNode()
    }

    private func addChildNode(_ parentID: UUID?) {
        selection = store.addChildNode(to: parentID)
    }

    private func addSiblingNode(_ nodeID: UUID?) {
        selection = store.addSiblingNode(after: nodeID)
    }

    private func moveNodeUp(_ nodeID: UUID?) {
        guard let nodeID else {
            return
        }

        selection = nodeID
        _ = store.moveNodeUp(nodeID)
    }

    private func moveNodeDown(_ nodeID: UUID?) {
        guard let nodeID else {
            return
        }

        selection = nodeID
        _ = store.moveNodeDown(nodeID)
    }

    private func indentNode(_ nodeID: UUID?) {
        guard let nodeID else {
            return
        }

        selection = nodeID
        _ = store.indentNode(nodeID)
        revealSelectionIfNeeded()
    }

    private func outdentNode(_ nodeID: UUID?) {
        guard let nodeID else {
            return
        }

        selection = nodeID
        _ = store.outdentNode(nodeID)
        revealSelectionIfNeeded()
    }

    private func delete(_ nodeID: UUID?) {
        guard let nodeID else {
            return
        }

        let nextSelection = store.preferredSelectionAfterDeleting(nodeID)
        store.deleteNode(with: nodeID)
        selection = nextSelection
    }

    private func seedExpandedNodesIfNeeded() {
        guard expandedNodeIDs.isEmpty else {
            return
        }

        expandedNodeIDs = Set(store.rootNodes.map(\.id))
    }

    private func revealSelectionIfNeeded() {
        guard autoExpandSelectionPath else {
            return
        }

        guard let selection, let path = pathToNode(selection, in: store.rootNodes) else {
            return
        }

        expandedNodeIDs.formUnion(path.dropLast())
    }

    private func pathToNode(_ id: UUID, in nodes: [ZettelNode]) -> [UUID]? {
        for node in nodes {
            if node.id == id {
                return [node.id]
            }

            if let childPath = pathToNode(id, in: node.children) {
                return [node.id] + childPath
            }
        }

        return nil
    }
}

private struct TreeSidebarView: View {
    let nodes: [ZettelNode]
    @Binding var selection: UUID?
    @Binding var expandedNodeIDs: Set<UUID>
    let density: SidebarDensity
    let showChildCounts: Bool
    let showGuides: Bool
    let totalNodeCount: Int
    let selectedPath: [String]
    let onCreateRoot: () -> Void
    let onOpenSettings: () -> Void
    let onAddChild: (UUID?) -> Void
    let onAddSibling: (UUID?) -> Void
    let onMoveUp: (UUID?) -> Void
    let onMoveDown: (UUID?) -> Void
    let onIndent: (UUID?) -> Void
    let onOutdent: (UUID?) -> Void
    let onDelete: (UUID?) -> Void
    let canMoveUp: (UUID?) -> Bool
    let canMoveDown: (UUID?) -> Bool
    let canIndent: (UUID?) -> Bool
    let canOutdent: (UUID?) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            TreeSidebarHeader(
                totalNodeCount: totalNodeCount,
                rootNodeCount: nodes.count,
                selectedPath: selectedPath,
                onCreateRoot: onCreateRoot,
                onOpenSettings: onOpenSettings
            )

            Divider()

            if nodes.isEmpty {
                ContentUnavailableView(
                    "No Nodes Yet",
                    systemImage: "tree",
                    description: Text("Create a root node, then shape years, topics, or any other branch beneath it.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: density.branchSpacing) {
                        ForEach(nodes) { node in
                            SidebarNodeBranch(
                                node: node,
                                depth: 0,
                                selection: $selection,
                                expandedNodeIDs: $expandedNodeIDs,
                                density: density,
                                showChildCounts: showChildCounts,
                                showGuides: showGuides,
                                onAddChild: onAddChild,
                                onAddSibling: onAddSibling,
                                onMoveUp: onMoveUp,
                                onMoveDown: onMoveDown,
                                onIndent: onIndent,
                                onOutdent: onOutdent,
                                onDelete: onDelete,
                                canMoveUp: canMoveUp,
                                canMoveDown: canMoveDown,
                                canIndent: canIndent,
                                canOutdent: canOutdent
                            )
                        }
                    }
                    .padding(12)
                }
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct TreeSidebarHeader: View {
    let totalNodeCount: Int
    let rootNodeCount: Int
    let selectedPath: [String]
    let onCreateRoot: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tree")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))

                    Text("\(totalNodeCount) nodes across \(rootNodeCount) root\(rootNodeCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    SidebarActionButton(
                        systemImage: "slider.horizontal.3",
                        accessibilityLabel: "Open Settings",
                        action: onOpenSettings
                    )

                    SidebarActionButton(
                        systemImage: "plus",
                        accessibilityLabel: "New Root Node",
                        action: onCreateRoot
                    )
                }
            }

            if selectedPath.isEmpty {
                Text("Sketch years, topics, and branches with a tree that behaves like an outline instead of a generic list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(selectedPath.joined(separator: " / "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    Color.accentColor.opacity(0.05),
                    Color(nsColor: .controlBackgroundColor),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct SidebarActionButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct SidebarNodeBranch: View {
    let node: ZettelNode
    let depth: Int
    @Binding var selection: UUID?
    @Binding var expandedNodeIDs: Set<UUID>
    let density: SidebarDensity
    let showChildCounts: Bool
    let showGuides: Bool
    let onAddChild: (UUID?) -> Void
    let onAddSibling: (UUID?) -> Void
    let onMoveUp: (UUID?) -> Void
    let onMoveDown: (UUID?) -> Void
    let onIndent: (UUID?) -> Void
    let onOutdent: (UUID?) -> Void
    let onDelete: (UUID?) -> Void
    let canMoveUp: (UUID?) -> Bool
    let canMoveDown: (UUID?) -> Bool
    let canIndent: (UUID?) -> Bool
    let canOutdent: (UUID?) -> Bool

    private var isSelected: Bool {
        selection == node.id
    }

    private var isExpanded: Bool {
        expandedNodeIDs.contains(node.id)
    }

    private var hasChildren: Bool {
        !node.children.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: density.branchSpacing) {
            HStack(spacing: density.rowSpacing) {
                TreeIndentGuides(depth: depth, density: density, showGuides: showGuides)

                expandCollapseControl

                Button {
                    selection = node.id
                } label: {
                    HStack(spacing: density.rowSpacing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: density.iconCornerRadius, style: .continuous)
                                .fill(iconBackground)

                            Image(systemName: iconName)
                                .font(.system(size: density.iconSize, weight: .semibold))
                                .foregroundStyle(iconForeground)
                        }
                        .frame(width: density.iconFrame, height: density.iconFrame)

                        VStack(alignment: .leading, spacing: density.metaSpacing) {
                            Text(node.displayTitle)
                                .font(density.titleFont)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if density.showsMetaLine {
                                HStack(spacing: 8) {
                                    if node.content != nil {
                                        Text("Rich note")
                                    } else if hasChildren {
                                        Text("Branch")
                                    } else {
                                        Text("Node")
                                    }

                                    Text(node.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        if node.content != nil {
                            Circle()
                                .fill(Color.accentColor.opacity(isSelected ? 0.95 : 0.75))
                                .frame(width: 7, height: 7)
                        }

                        if showChildCounts, hasChildren {
                            Text("\(node.children.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                                )
                        }
                    }
                    .padding(.vertical, density.rowVerticalPadding)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(rowBackground)
                    .overlay(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.16))
                            .frame(width: 3, height: density.selectionBarHeight)
                            .padding(.leading, 8)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("New Child Node") {
                        selection = node.id
                        onAddChild(node.id)
                    }

                    Button("New Sibling Node") {
                        selection = node.id
                        onAddSibling(node.id)
                    }

                    Divider()

                    Button("Move Up") {
                        selection = node.id
                        onMoveUp(node.id)
                    }
                    .disabled(!canMoveUp(node.id))

                    Button("Move Down") {
                        selection = node.id
                        onMoveDown(node.id)
                    }
                    .disabled(!canMoveDown(node.id))

                    Button("Indent") {
                        selection = node.id
                        onIndent(node.id)
                    }
                    .disabled(!canIndent(node.id))

                    Button("Outdent") {
                        selection = node.id
                        onOutdent(node.id)
                    }
                    .disabled(!canOutdent(node.id))

                    Divider()

                    Button("Delete Node", role: .destructive) {
                        onDelete(node.id)
                    }
                }
            }

            if isExpanded {
                ForEach(node.children) { child in
                    SidebarNodeBranch(
                        node: child,
                        depth: depth + 1,
                        selection: $selection,
                        expandedNodeIDs: $expandedNodeIDs,
                        density: density,
                        showChildCounts: showChildCounts,
                        showGuides: showGuides,
                        onAddChild: onAddChild,
                        onAddSibling: onAddSibling,
                        onMoveUp: onMoveUp,
                        onMoveDown: onMoveDown,
                        onIndent: onIndent,
                        onOutdent: onOutdent,
                        onDelete: onDelete,
                        canMoveUp: canMoveUp,
                        canMoveDown: canMoveDown,
                        canIndent: canIndent,
                        canOutdent: canOutdent
                    )
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: expandedNodeIDs)
    }

    private var expandCollapseControl: some View {
        Group {
            if hasChildren {
                Button {
                    if isExpanded {
                        expandedNodeIDs.remove(node.id)
                    } else {
                        expandedNodeIDs.insert(node.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: density.disclosureWidth, height: density.disclosureWidth)
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.28))
                    .frame(width: 6, height: 6)
                    .frame(width: density.disclosureWidth, height: density.disclosureWidth)
            }
        }
    }

    private var iconName: String {
        if hasChildren {
            return isExpanded ? "square.stack.3d.down.forward.fill" : "square.stack.3d.up.fill"
        }

        return node.content == nil ? "square.text.square" : "doc.richtext.fill"
    }

    private var iconBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.18)
        }

        return hasChildren ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1)
    }

    private var iconForeground: Color {
        if isSelected {
            return .accentColor
        }

        return hasChildren ? .accentColor : .secondary
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: density.rowCornerRadius, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035))
    }
}

private struct TreeIndentGuides: View {
    let depth: Int
    let density: SidebarDensity
    let showGuides: Bool

    var body: some View {
        HStack(spacing: density.guideSpacing) {
            ForEach(0..<depth, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(showGuides ? Color.secondary.opacity(0.16) : .clear)
                    .frame(width: 2, height: density.guideHeight)
            }
        }
        .frame(width: CGFloat(depth) * density.guideStep, alignment: .leading)
    }
}

private struct NodeDetailView: View {
    let node: ZettelNode
    let titlePath: [String]
    let showMetadata: Bool
    let onTitleChange: (String) -> Void
    let onContentChange: (Data?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !titlePath.isEmpty {
                Text(titlePath.joined(separator: " / "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            TextField(
                "Node title",
                text: Binding(
                    get: { node.title },
                    set: onTitleChange
                )
            )
            .textFieldStyle(.roundedBorder)
            .font(.title2.weight(.semibold))

            HStack {
                Label("Paste formatted text or images directly into the editor.", systemImage: "photo.on.rectangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                if showMetadata {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Created \(node.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        Text("Updated \(node.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            RichTextEditor(data: node.content, onChange: onContentChange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
