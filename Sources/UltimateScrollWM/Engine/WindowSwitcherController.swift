import AppKit
import SwiftUI

/// `⌥Tab` pencere seçici.
///
/// Windows'taki `Alt+Tab` gibi çalışır:
///   1. `⌥Tab` → panel açılır (liste **bir kez** alınır, minimize pencereler dahil)
///   2. `⌥` basılı tutup `Tab`'a basmaya devam → pencereler arasında gez
///   3. `⌥` bırakılınca → seçim uygulanır (minimize ise geri açılır)
///   4. `Esc` → iptal
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

        // Liste YALNIZCA oturum başında alınır. Her basışta yeniden alınırsa
        // seçim gerçek odaktaki pencereye geri sıfırlanır ve gezmek imkânsız olur.
        if !isActive {
            engine.beginSwitcherSession()
            guard !engine.state.windows.isEmpty else { return }
            beginSessionIfNeeded()
        }

        if direction > 0 {
            engine.selectNextForSwitcher()
        } else {
            engine.selectPreviousForSwitcher()
        }

        present(engine: engine)
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
        engine?.endSwitcherSession()
    }

    // MARK: - Panel

    private func present(engine: StripEngine) {
        if panel == nil {
            let hosting = NSHostingView(rootView: WindowSwitcherView(engine: engine))
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.level = .statusBar
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.isMovable = false
            newPanel.contentView = hosting
            panel = newPanel
        }

        guard let panel, let hosting = panel.contentView else { return }

        // İçerik boyutu pencere sayısına göre değişir; kendini ölçmesine izin ver.
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 1 || size.height < 1 {
            size = hosting.intrinsicContentSize
        }
        panel.setContentSize(size)

        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            ))
        }
        panel.orderFrontRegardless()
    }
}
