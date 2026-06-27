import AppKit
import Foundation

enum WorkspaceOpener {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
