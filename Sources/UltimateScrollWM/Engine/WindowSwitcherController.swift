import AppKit
import SwiftUI

/// `⌥Tab` pencere seçici.
///
/// macOS'un `⌘Tab` mantığını izler:
///   1. `⌥Tab` → panel açılır
///   2. `⌥` basılı tutup `Tab`'a basmaya devam → pencereler arasında gez
///   3. `⌥` bırakılınca → seçim uygulanır
///   4. `Esc` → iptal
///
/// Önceden son tuştan 0.9 sn sonra kendiliğinden onaylıyordu; bu yüzden panel
/// "hemen kapanıyor" gibi görünüyordu ve gezmek imkânsızdı.
@MainActor
final class WindowSwitcherController {
    private weak var engine: StripEngine?
    private var panel: NSPanel?

    /// `⌥` bırakılışını yakalayan genel izleyici (Erişilebilirlik izni gerektirir).
    private var flagsMonitor: Any?
    /// `Esc` ile iptal için genel tuş izleyici.
    private var keyMonitor: Any?
    /// `⌥` bırakılışı kaçırılırsa panelin takılı kalmasını önleyen emniyet zamanlayıcısı.
    private var safetyWorkItem: DispatchWorkItem?
    private var isActive = false

    init(engine: StripEngine) {
        self.engine = engine
    }

    func showNext() { show(direction: 1) }
    func showPrevious() { show(direction: -1) }

    // MARK: - Oturum

    private func show(direction: Int) {
        guard let engine else { return }
        engine.refreshWindows()
        guard !engine.state.windows.isEmpty else { return }

        if direction > 0 {
            engine.selectNextForSwitcher()
        } else {
            engine.selectPreviousForSwitcher()
        }

        present(engine: engine)
        beginSessionIfNeeded()
        scheduleSafety()
    }

    /// Seçimi uygular ve paneli kapatır (`⌥` bırakıldığında).
    func commit() {
        guard isActive else { return }
        engine?.activateSwitcherSelection()
        endSession()
    }

    /// İptal eder, seçimi uygulamaz (`Esc`).
    func cancel() {
        guard isActive else { return }
        endSession()
    }

    private func beginSessionIfNeeded() {
        guard !isActive else { return }
        isActive = true

        // ⌥ bırakılınca onayla.
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard !event.modifierFlags.contains(.option) else { return }
            DispatchQueue.main.async { self?.commit() }
        }

        // Esc ile iptal.
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return } // Esc
            DispatchQueue.main.async { self?.cancel() }
        }
    }

    /// İzleyici kurulamadıysa (izin yoksa) kısa, kurulduysa uzun bir emniyet
    /// süresi kullan; panel hiçbir durumda ekranda takılı kalmasın.
    private func scheduleSafety() {
        safetyWorkItem?.cancel()
        let delay: TimeInterval = flagsMonitor == nil ? 1.5 : 10.0
        let item = DispatchWorkItem { [weak self] in self?.commit() }
        safetyWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func endSession() {
        isActive = false
        safetyWorkItem?.cancel()
        safetyWorkItem = nil
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        panel?.orderOut(nil)
    }

    // MARK: - Panel

    private func present(engine: StripEngine) {
        let visibleCount = min(engine.state.windows.count, 6)
        let width = CGFloat(visibleCount * 156 + 36)
        let height: CGFloat = 165

        if panel == nil {
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.level = .statusBar
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            panel = newPanel
        }

        panel?.setContentSize(NSSize(width: width, height: height))
        panel?.contentView = NSHostingView(rootView: WindowSwitcherView(engine: engine))

        if let screen = NSScreen.main, let panel {
            panel.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - panel.frame.width / 2,
                y: screen.visibleFrame.midY - panel.frame.height / 2
            ))
        }
        panel?.orderFrontRegardless()
    }
}
