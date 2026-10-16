import SwiftUI
import AppKit

@main
struct UltimateScrollWMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var engine = StripEngine.shared
    @StateObject private var backend = PaneruService.shared
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(engine: engine, backend: backend)
        } label: {
            Label("USWM", systemImage: "rectangle.split.3x1")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Uygulama yaşam döngüsü
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var windowSwitcher: WindowSwitcherController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let engine = StripEngine.shared
        let switcher = WindowSwitcherController(engine: engine)
        windowSwitcher = switcher
        engine.start()
        PaneruService.shared.start()
        HotKeyManager.shared.onSwitcherNext = { [weak switcher] in switcher?.showNext() }
        HotKeyManager.shared.onSwitcherPrevious = { [weak switcher] in switcher?.showPrevious() }
        HotKeyManager.shared.start()

        // Ayarlar penceresini yalnızca gerçekten gerektiğinde aç:
        // ilk açılışta, `--settings` ile istendiğinde veya erişilebilirlik izni
        // eksikse. Aksi hâlde menü çubuğunda sessizce başla.
        let firstRun = !UserDefaults.standard.bool(forKey: Self.firstRunKey)
        if firstRun { UserDefaults.standard.set(true, forKey: Self.firstRunKey) }
        let requested = CommandLine.arguments.contains("--settings")
        if firstRun || requested || !engine.hasPermission {
            showSettings()
        }

        Diagnostics.write()

        // İzin sonradan verilirse (Sistem Ayarları'nda) uygulamayı yeniden
        // başlatmak gerekmesin: izni izle, gelince motoru canlandır.
        if !engine.hasPermission { watchPermission() }
    }

    private static let firstRunKey = "UltimateScrollWM.hasLaunchedBefore"
    private var permissionTimer: Timer?

    /// Eksik Erişilebilirlik iznini birkaç saniyede bir yoklar.
    ///
    /// macOS izni çalışan sürece hemen yansıtmaz ve `AXIsProcessTrusted` süreç
    /// başına önbelleğe alır; bu yüzden izin gelince motor yeniden başlatılır.
    private func watchPermission() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in
                let engine = StripEngine.shared
                engine.checkPermission()
                Diagnostics.write()
                if engine.hasPermission {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                    engine.start()
                    // Motor da izne ihtiyaç duyar; süreç başına önbelleği tazele.
                    PaneruService.shared.restart()
                }
            }
        }
    }

    func showSettings() {
        if settingsWindow == nil {
            let root = SettingsView(engine: StripEngine.shared, backend: PaneruService.shared)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = "UltimateScrollWM"
            window.setContentSize(NSSize(width: 980, height: 680))
            window.minSize = NSSize(width: 900, height: 620)
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        PaneruService.shared.stop()
        HotKeyManager.shared.stop()
    }
}
