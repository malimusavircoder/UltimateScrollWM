import Foundation
import ApplicationServices

/// Represents a single managed window
struct WindowInfo: Identifiable, Equatable {
    let id: AXUIElement
    let pid: pid_t
    let appName: String
    var title: String
    var frame: CGRect
    var isFloating: Bool = false
    var isMinimized: Bool = false
    
    // For strip positioning
    var columnIndex: Int = 0
    var preferredWidth: CGFloat = 0   // 0 = use default
    
    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        CFEqual(lhs.id, rhs.id)
    }
}
