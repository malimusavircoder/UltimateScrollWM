import Foundation
import CoreGraphics
import ApplicationServices

/// The entire horizontal strip of windows
struct StripState {
    var windows: [WindowInfo] = []
    var focusedIndex: Int = 0
    var scrollOffset: CGFloat = 0      // How much the strip is scrolled
    var gap: CGFloat = 8
    var defaultWidthRatio: CGFloat = 0.5   // 50% of screen by default
    
    var focusedWindow: WindowInfo? {
        guard windows.indices.contains(focusedIndex) else { return nil }
        return windows[focusedIndex]
    }
    
    mutating func addWindow(_ window: WindowInfo) {
        // Insert right after focused window
        let insertIndex = min(focusedIndex + 1, windows.count)
        var newWindow = window
        newWindow.columnIndex = insertIndex
        windows.insert(newWindow, at: insertIndex)
        
        // Update indices
        for i in windows.indices {
            windows[i].columnIndex = i
        }
        
        focusedIndex = insertIndex
    }
    
    mutating func removeWindow(id: AXUIElement) {
        guard let index = windows.firstIndex(where: { CFEqual($0.id, id) }) else { return }
        windows.remove(at: index)
        
        for i in windows.indices {
            windows[i].columnIndex = i
        }
        
        if focusedIndex >= windows.count {
            focusedIndex = max(0, windows.count - 1)
        }
    }
    
    mutating func focusNext() {
        guard !windows.isEmpty else { return }
        focusedIndex = (focusedIndex + 1) % windows.count
    }
    
    mutating func focusPrevious() {
        guard !windows.isEmpty else { return }
        focusedIndex = (focusedIndex - 1 + windows.count) % windows.count
    }

    mutating func moveFocused(by offset: Int) {
        guard windows.indices.contains(focusedIndex) else { return }
        let destination = focusedIndex + offset
        guard windows.indices.contains(destination) else { return }
        windows.swapAt(focusedIndex, destination)
        focusedIndex = destination
        for index in windows.indices {
            windows[index].columnIndex = index
        }
    }
}
