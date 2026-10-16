import Foundation
import ApplicationServices

extension AXUIElement: @retroactive Equatable {
    public static func == (lhs: AXUIElement, rhs: AXUIElement) -> Bool {
        CFEqual(lhs, rhs)
    }
}

extension AXUIElement: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(self))
    }
}
