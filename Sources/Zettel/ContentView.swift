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
    @State private var searchText = ""

    private var selectedNode: ZettelNode? {
        store.node(with: selection)
    }

    private var sidebarDensity: SidebarDensity {
        SidebarDensity(rawValue: sidebarDensityRawValue) ?? .comfortable
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFiltering: Bool {
        !normalizedSearchText.isEmpty
    }

    private var displayedNodes: [ZettelNode] {
        guard isFiltering else {
            return store.rootNodes
        }

        return filter(nodes: store.rootNodes, matching: normalizedSearchText)
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
                nodes: displayedNodes,
                searchText: $searchText,
                selection: $selection,
                expandedNodeIDs: $expandedNodeIDs,
                density: sidebarDensity,
                showChildCounts: showSidebarChildCounts,
                showGuides: showTreeGuides,
                totalNodeCount: countNodes(in: store.rootNodes),
                visibleNodeCount: countNodes(in: displayedNodes),
                isFiltering: isFiltering,
                selectedPath: store.titlePath(for: selection),
                onCreateRoot: addRootNode,
                onOpenSettings: AppWindowController.openSettings,
                onExpandAll: expandAllDisplayedNodes,
                onCollapseAll: collapseTree,
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
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 380)
        } detail: {
            if let selectedNode {
                NodeDetailView(
                    node: selectedNode,
                    titlePath: store.titlePath(for: selectedNode.id),
                    showMetadata: showNodeMetadata,
                    onTitleChange: { store.updateTitle(for: selectedNode.id, title: $0) },
                    onContentChange: { store.updateContent(for: selectedNode.id, content: $0) },
                    onCreateChild: { addChildNode(selectedNode.id) },
                    onCreateSibling: { addSiblingNode(selectedNode.id) },
                    onDelete: { delete(selectedNode.id) }
                )
                .id(selectedNode.id)
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
                .keyboardShortcut("n", modifiers: [.command])

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
        .onChange(of: searchText) { _, _ in
            guard isFiltering else {
                return
            }

            if let selection, contains(nodeID: selection, in: displayedNodes) {
                return
            }

            selection = firstNodeID(in: displayedNodes)
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

    private func expandAllDisplayedNodes() {
        withAnimation(.snappy(duration: 0.18)) {
            expandedNodeIDs.formUnion(allExpandableNodeIDs(in: displayedNodes))
        }
    }

    private func collapseTree() {
        withAnimation(.snappy(duration: 0.18)) {
            expandedNodeIDs = []
        }
    }

    private func filter(nodes: [ZettelNode], matching query: String) -> [ZettelNode] {
        nodes.compactMap { node in
            let filteredChildren = filter(nodes: node.children, matching: query)
            let matches = node.displayTitle.localizedCaseInsensitiveContains(query)

            guard matches || !filteredChildren.isEmpty else {
                return nil
            }

            var copy = node
            copy.children = filteredChildren
            return copy
        }
    }

    private func countNodes(in nodes: [ZettelNode]) -> Int {
        nodes.reduce(0) { partialResult, node in
            partialResult + 1 + countNodes(in: node.children)
        }
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

    private func allExpandableNodeIDs(in nodes: [ZettelNode]) -> Set<UUID> {
        nodes.reduce(into: Set<UUID>()) { partialResult, node in
            if !node.children.isEmpty {
                partialResult.insert(node.id)
            }

            partialResult.formUnion(allExpandableNodeIDs(in: node.children))
        }
    }

    private func contains(nodeID: UUID, in nodes: [ZettelNode]) -> Bool {
        nodes.contains { node in
            node.id == nodeID || contains(nodeID: nodeID, in: node.children)
        }
    }

    private func firstNodeID(in nodes: [ZettelNode]) -> UUID? {
        nodes.first?.id
    }
}

private struct TreeSidebarView: View {
    let nodes: [ZettelNode]
    @Binding var searchText: String
    @Binding var selection: UUID?
    @Binding var expandedNodeIDs: Set<UUID>
    let density: SidebarDensity
    let showChildCounts: Bool
    let showGuides: Bool
    let totalNodeCount: Int
    let visibleNodeCount: Int
    let isFiltering: Bool
    let selectedPath: [String]
    let onCreateRoot: () -> Void
    let onOpenSettings: () -> Void
    let onExpandAll: () -> Void
    let onCollapseAll: () -> Void
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
            SidebarHeader(
                searchText: $searchText,
                totalNodeCount: totalNodeCount,
                visibleNodeCount: visibleNodeCount,
                isFiltering: isFiltering,
                selectedPath: selectedPath,
                onCreateRoot: onCreateRoot,
                onOpenSettings: onOpenSettings,
                onExpandAll: onExpandAll,
                onCollapseAll: onCollapseAll
            )

            Divider()

            if totalNodeCount == 0 {
                ContentUnavailableView(
                    "No Nodes Yet",
                    systemImage: "tree",
                    description: Text("Create a root node, then shape years, topics, or any other branch beneath it.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if nodes.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try a broader term or clear the filter to return to the full outline.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                forceExpanded: isFiltering,
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
                    .padding(10)
                }
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct SidebarHeader: View {
    @Binding var searchText: String
    let totalNodeCount: Int
    let visibleNodeCount: Int
    let isFiltering: Bool
    let selectedPath: [String]
    let onCreateRoot: () -> Void
    let onOpenSettings: () -> Void
    let onExpandAll: () -> Void
    let onCollapseAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nodes")
                        .font(.title3.weight(.semibold))

                    Text(isFiltering ? "\(visibleNodeCount) matching" : "\(totalNodeCount) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)

                Button(action: onCreateRoot) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }

            TextField("Filter nodes", text: $searchText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Expand All", action: onExpandAll)
                Button("Collapse All", action: onCollapseAll)
            }
            .buttonStyle(.link)
            .font(.caption)

            if !selectedPath.isEmpty {
                Text(selectedPath.joined(separator: " / "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
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
    let forceExpanded: Bool
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
        forceExpanded || expandedNodeIDs.contains(node.id)
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
                        Image(systemName: hasChildren ? "folder" : "doc.text")
                            .frame(width: density.iconFrame, height: density.iconFrame)
                            .foregroundStyle(hasChildren ? Color.accentColor : .secondary)

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

                        if showChildCounts, hasChildren {
                            Text("\(node.children.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, density.rowVerticalPadding)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(rowBackground)
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
                        forceExpanded: forceExpanded,
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
                    if isExpanded, !forceExpanded {
                        expandedNodeIDs.remove(node.id)
                    } else if !forceExpanded {
                        expandedNodeIDs.insert(node.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: density.disclosureWidth, height: density.disclosureWidth)
                }
                .buttonStyle(.plain)
                .disabled(forceExpanded)
            } else {
                Color.clear
                    .frame(width: density.disclosureWidth, height: density.disclosureWidth)
            }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: density.rowCornerRadius, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
    }
}

private struct TreeIndentGuides: View {
    let depth: Int
    let density: SidebarDensity
    let showGuides: Bool

    var body: some View {
        HStack(spacing: density.guideSpacing) {
            ForEach(0..<depth, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(showGuides ? Color.secondary.opacity(0.18) : .clear)
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
    let onCreateChild: () -> Void
    let onCreateSibling: () -> Void
    let onDelete: () -> Void

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
                if showMetadata {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Created \(node.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        Text("Updated \(node.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Button("Child", action: onCreateChild)
                    Button("Sibling", action: onCreateSibling)
                    Button("Delete", role: .destructive, action: onDelete)
                }
                .buttonStyle(.bordered)
            }

            RichTextEditor(nodeID: node.id, data: node.content, onChange: onContentChange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
