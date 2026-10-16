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
}
