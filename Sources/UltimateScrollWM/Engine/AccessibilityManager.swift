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
    
    /// Çalışan normal (Dock'ta görünen) uygulamaların pencerelerini döndürür.
    ///
    /// - Parameter includeMinimized: `true` ise `⌘M` ile simge durumuna
    ///   küçültülmüş pencereler de listelenir (pencere seçici için gerekli).
    func getAllWindows(includeMinimized: Bool = false) -> [WindowInfo] {
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
                let minimized = isMinimized(window)

                // Minimize pencereler yalnızca istenirse listelenir.
                if minimized && !includeMinimized { continue }
                if !minimized && !isWindowVisible(window) { continue }

                // Minimize pencerelerin konumu/boyutu güvenilir olmayabilir; onlar
                // için küçüklük filtresini uygulamıyoruz.
                guard var info = windowInfo(
                    from: window,
                    pid: app.processIdentifier,
                    appName: app.localizedName ?? "Unknown",
                    allowSmall: minimized
                ) else { continue }

                info.isMinimized = minimized
                result.append(info)
            }
        }

        return result
    }

    private func windowInfo(
        from element: AXUIElement,
        pid: pid_t,
        appName: String,
        allowSmall: Bool = false
    ) -> WindowInfo? {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String ?? ""

        let frame = getFrame(of: element) ?? .zero

        // Çok küçük pencereler gerçek içerik penceresi değildir.
        if !allowSmall && (frame.width < 100 || frame.height < 80) { return nil }

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
    
    /// Pencereyi öne getirir, odağı ona verir ve minimize ise geri açar.
    ///
    /// Sıra önemli: önce uygulama öne gelmeli, yoksa `⌘M` ile küçültülmüş bir
    /// pencere geri açılmaz.
    func raiseWindow(_ element: AXUIElement) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else {
            AXUIElementPerformAction(element, kAXRaiseAction as CFString)
            return
        }

        // 1) Uygulamayı öne getir.
        NSRunningApplication(processIdentifier: pid)?
            .activate(options: [.activateIgnoringOtherApps])

        // 2) Minimize ise geri aç.
        var minimizedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
           (minimizedRef as? Bool) == true {
            AXUIElementSetAttributeValue(
                element,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
        }

        // 3) Pencereyi öne al.
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)

        // 4) Odağı bu pencereye ver.
        AXUIElementSetAttributeValue(
            AXUIElementCreateApplication(pid),
            kAXFocusedWindowAttribute as CFString,
            element
        )
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
