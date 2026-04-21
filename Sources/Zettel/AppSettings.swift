import AppKit
import SwiftUI

enum AppSettingKey {
    static let sidebarDensity = "zettel.sidebarDensity"
    static let showSidebarChildCounts = "zettel.showSidebarChildCounts"
    static let showTreeGuides = "zettel.showTreeGuides"
    static let showNodeMetadata = "zettel.showNodeMetadata"
    static let autoExpandSelectionPath = "zettel.autoExpandSelectionPath"
}

enum SidebarDensity: String, CaseIterable, Identifiable {
    case compact
    case comfortable

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .compact:
            return "Compact"
        case .comfortable:
            return "Comfortable"
        }
    }

    var rowSpacing: CGFloat {
        switch self {
        case .compact:
            return 8
        case .comfortable:
            return 10
        }
    }

    var branchSpacing: CGFloat {
        switch self {
        case .compact:
            return 4
        case .comfortable:
            return 8
        }
    }

    var rowVerticalPadding: CGFloat {
        switch self {
        case .compact:
            return 6
        case .comfortable:
            return 9
        }
    }

    var rowCornerRadius: CGFloat {
        switch self {
        case .compact:
            return 10
        case .comfortable:
            return 12
        }
    }

    var selectionBarHeight: CGFloat {
        switch self {
        case .compact:
            return 22
        case .comfortable:
            return 28
        }
    }

    var disclosureWidth: CGFloat {
        switch self {
        case .compact:
            return 14
        case .comfortable:
            return 16
        }
    }

    var iconFrame: CGFloat {
        switch self {
        case .compact:
            return 24
        case .comfortable:
            return 28
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact:
            return 11
        case .comfortable:
            return 12
        }
    }

    var iconCornerRadius: CGFloat {
        switch self {
        case .compact:
            return 7
        case .comfortable:
            return 8
        }
    }

    var titleFont: Font {
        switch self {
        case .compact:
            return .body
        case .comfortable:
            return .body.weight(.medium)
        }
    }

    var showsMetaLine: Bool {
        switch self {
        case .compact:
            return false
        case .comfortable:
            return true
        }
    }

    var metaSpacing: CGFloat {
        switch self {
        case .compact:
            return 0
        case .comfortable:
            return 2
        }
    }

    var guideSpacing: CGFloat {
        switch self {
        case .compact:
            return 8
        case .comfortable:
            return 10
        }
    }

    var guideStep: CGFloat {
        switch self {
        case .compact:
            return 10
        case .comfortable:
            return 12
        }
    }

    var guideHeight: CGFloat {
        switch self {
        case .compact:
            return 14
        case .comfortable:
            return 18
        }
    }
}

enum AppWindowController {
    static func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
