import Foundation
import ApplicationServices

/// Teşhis bilgilerini bir metin dosyasına yazar.
///
/// Neden? Ad-hoc imzada macOS Erişilebilirlik iznini ikili dosyanın parmak izine
/// bağladığı için izin her yeniden derlemede düşebiliyor. Uygulamanın kendini
/// izinli görüp görmediğini dışarıdan anlamanın tek yolu bu dosya.
///
/// Yol: `~/Library/Application Support/UltimateScrollWM/durum.txt`
@MainActor
enum Diagnostics {

    static var directory: URL? {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("UltimateScrollWM", isDirectory: true)
    }

    static func write() {
        guard let directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Süreç kendi Erişilebilirlik iznini buradan öğrenir.
        let trusted = AXIsProcessTrusted()

        let text = """
        zaman: \(ISO8601DateFormatter().string(from: Date()))
        uygulamaYolu: \(Bundle.main.bundlePath)
        uygulamaErisilebilirlikIzni: \(trusted)
        motorIzni: \(StripEngine.shared.hasPermission)
        paneruCalisiyor: \(PaneruService.shared.isRunning)
        paneruPID: \(PaneruService.shared.pid.map(String.init) ?? "-")
        paneruGunluk: \(PaneruService.shared.logURL?.path ?? "-")
        """
        try? text.write(to: directory.appendingPathComponent("durum.txt"), atomically: true, encoding: .utf8)
    }

    /// Pencere seçicinin (⌥Tab) gördüğü listeyi yazar.
    ///
    /// Neden? Seçici Erişilebilirlik izniyle çalışır; dışarıdan (izinsiz bir
    /// süreçten) aynı listeyi görmek mümkün değildir. Bu dosya, seçicinin kaç
    /// pencere bulduğunu ve hangilerinin minimize olduğunu doğrulamayı sağlar.
    ///
    /// Yol: `~/Library/Application Support/UltimateScrollWM/secici.txt`
    static func dumpSwitcherWindows(_ windows: [WindowInfo]) {
        guard let directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var lines = [
            "zaman: \(ISO8601DateFormatter().string(from: Date()))",
            "pencereSayisi: \(windows.count)",
            "",
            "sira\tdurum\tuygulama\tbaslik\trol\tcerceve",
        ]
        for (index, window) in windows.enumerated() {
            let frame = "\(Int(window.frame.origin.x)),\(Int(window.frame.origin.y)) "
                + "\(Int(window.frame.width))x\(Int(window.frame.height))"
            let title = window.title.isEmpty ? "(basliksiz)" : window.title
            let state = window.isMinimized ? "minimize" : "acik"
            let subrole = window.subrole.isEmpty ? "-" : window.subrole
            lines.append("\(index)\t\(state)\t\(window.appName)\t\(title)\t\(subrole)\t\(frame)")
        }

        try? lines.joined(separator: "\n")
            .write(to: directory.appendingPathComponent("secici.txt"), atomically: true, encoding: .utf8)
    }
}
