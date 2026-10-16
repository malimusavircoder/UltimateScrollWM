import Foundation
import AppKit
import Carbon.HIToolbox

/// Global hotkey handler for MVP (⌃⌥ ← →)
final class HotKeyManager {
    
    static let shared = HotKeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    
    var onFocusNext: (() -> Void)?
    var onFocusPrevious: (() -> Void)?
    var onMoveNext: (() -> Void)?
    var onMovePrevious: (() -> Void)?
    var onCycleWidth: (() -> Void)?
    var onFullWidth: (() -> Void)?
    var onCenter: (() -> Void)?
    var onSwitcherNext: (() -> Void)?
    var onSwitcherPrevious: (() -> Void)?
    
    private init() {}
    
    func start() {
        stop()
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let userData = Unmanaged.passUnretained(self).toOpaque()
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                DispatchQueue.main.async {
                    switch hotKeyID.id {
                    case 1: manager.onFocusNext?()
                    case 2: manager.onFocusPrevious?()
                    case 3: manager.onMoveNext?()
                    case 4: manager.onMovePrevious?()
                    case 5: manager.onCycleWidth?()
                    case 6: manager.onFullWidth?()
                    case 7: manager.onCenter?()
                    case 8: manager.onSwitcherNext?()
                    case 9: manager.onSwitcherPrevious?()
                    default: break
                    }
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
        
        guard status == noErr else {
            print("HotKeyManager: Event handler kurulamadı → \(status)")
            return
        }
        
        // The bundled window engine owns all layout shortcuts. This manager
        // reserves only the Windows-style switcher shortcuts.
        registerHotKey(keyCode: UInt32(kVK_Tab), modifiers: UInt32(optionKey), id: 8)
        registerHotKey(keyCode: UInt32(kVK_Tab), modifiers: UInt32(optionKey | shiftKey), id: 9)
        
        print("HotKeyManager: Kısayollar kaydedildi (⌃⌥ ← →)")
    }
    
    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5553574D), id: id) // "USWM"
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
        } else {
            print("HotKeyManager: Kısayol kaydedilemedi (id: \(id)) → \(status)")
        }
    }
    
    func stop() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}
