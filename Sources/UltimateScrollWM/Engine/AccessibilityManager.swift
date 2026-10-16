import Foundation
import ApplicationServices
import AppKit

/// Handles all Accessibility API interactions
final class AccessibilityManager {
    
    static let shared = AccessibilityManager()
    
    private init() {}
    
    // MARK: - Permission
    
    func checkPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Window Discovery
    
    func getAllWindows() -> [WindowInfo] {
        var result: [WindowInfo] = []
        
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }
        
        for app in runningApps {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            
            var windowsRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
            
            guard status == .success, let windows = windowsRef as? [AXUIElement] else { continue }
            
            for window in windows {
                if let info = windowInfo(from: window, pid: app.processIdentifier, appName: app.localizedName ?? "Unknown") {
                    // Skip minimized and invisible windows
                    if isWindowVisible(window) && !isMinimized(window) {
                        result.append(info)
                    }
                }
            }
        }
        
        return result
    }
    
    private func windowInfo(from element: AXUIElement, pid: pid_t, appName: String) -> WindowInfo? {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String ?? ""
        
        guard let frame = getFrame(of: element) else { return nil }
        
        // Skip very small windows (likely not real content windows)
        if frame.width < 100 || frame.height < 80 { return nil }
        
        return WindowInfo(
            id: element,
            pid: pid,
            appName: appName,
            title: title,
            frame: frame
        )
    }
    
    // MARK: - Window Attributes
    
    func getFrame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionValue = positionRef,
              let sizeValue = sizeRef else { return nil }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        guard CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }

        if AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) &&
           AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
            return CGRect(origin: position, size: size)
        }
        return nil
    }

    func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success else { return nil }
        return value.map { unsafeBitCast($0, to: AXUIElement.self) }
    }
    
    func setFrame(of element: AXUIElement, to frame: CGRect) {
        var position = frame.origin
        var size = frame.size
        
        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        }
    }
    
    func raiseWindow(_ element: AXUIElement) {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        
        // Also activate the application
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) == .success {
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }
    
    private func isWindowVisible(_ element: AXUIElement) -> Bool {
        // Basic check – more sophisticated filtering can be added later
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value) == .success {
            if let minimized = value as? Bool, minimized { return false }
        }
        return true
    }
    
    private func isMinimized(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }
}
