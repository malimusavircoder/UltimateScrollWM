import AppKit
import ScreenCaptureKit

/// `⌥Tab` seçicisi için pencere önizlemeleri üretir.
///
/// Neden ScreenCaptureKit? macOS 15'te `CGWindowListCreateImage` **kaldırıldı**;
/// macOS 27 SDK'sında artık derlenmiyor bile ("Please use ScreenCaptureKit
/// instead"). Bu yüzden tek yol bu çerçeve.
///
/// Önizleme **Ekran Kaydı izni** gerektirir. İzin yoksa `thumbnail` `nil` döner
/// ve arayüz uygulama simgesine düşer: özellik sessizce devre dışı kalır,
/// seçici bozulmaz.
@MainActor
final class WindowThumbnailProvider {
    static let shared = WindowThumbnailProvider()

    private var imageCache: [String: NSImage] = [:]
    private var contentTask: Task<[SCWindow], Never>?
    /// Yakalama işlerinin kuyruğu (bkz. `serialized`).
    private var captureChain: Task<Void, Never>?

    private init() {}

    // MARK: - İzin

    /// Ekran Kaydı izni verilmiş mi?
    var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// Sistemden izin ister. İzin verildikten sonra uygulamanın yeniden
    /// başlatılması gerekir (macOS'un kuralı).
    @discardableResult
    func requestPermission() -> Bool { CGRequestScreenCaptureAccess() }

    /// Ekran Kaydı ayarlarını açar.
    func openPermissionSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Oturum

    /// Seçici kapanınca çağrılır: pencere listesi bir sonraki açılışta yeniden
    /// çekilir (güncel pencereler görünsün). Görüntü önbelleği korunur.
    func endSession() {
        contentTask = nil
    }

    // MARK: - Önizleme

    /// Verilen pencere için küçük bir görüntü üretir; olmazsa `nil`.
    func thumbnail(for window: WindowInfo, size: CGSize) async -> NSImage? {
        guard hasPermission else { return nil }
        guard #available(macOS 14.0, *) else { return nil }

        let key = cacheKey(for: window)
        if let cached = imageCache[key] { return cached }

        let windows = await shareableWindows()
        guard let target = match(window, in: windows) else { return nil }

        let olcek: CGFloat = 2 // Retina
        let image = await serialized { () -> NSImage? in
            let ayar = SCStreamConfiguration()
            ayar.width = max(32, Int(size.width * olcek))
            ayar.height = max(32, Int(size.height * olcek))
            ayar.showsCursor = false
            ayar.ignoreShadowsSingleWindow = true

            let filtre = SCContentFilter(desktopIndependentWindow: target)
            guard let cgImage = try? await SCScreenshotManager.captureImage(
                contentFilter: filtre,
                configuration: ayar
            ) else { return nil }

            return NSImage(cgImage: cgImage, size: size)
        }

        guard let image else { return nil }

        // Önbellek sınırsız büyümesin.
        if imageCache.count > 64 { imageCache.removeAll() }
        imageCache[key] = image
        return image
    }

    /// Yakalamaları **sıraya koyar**.
    ///
    /// Her yakalama kendi akışını açıyor; 20 hücre aynı anda isterse pencere
    /// sunucusu boğulur ve panel geç açılır. Sırayla yapınca hücreler tek tek
    /// dolar, panel hemen tepki verir.
    private func serialized(_ work: @escaping () async -> NSImage?) async -> NSImage? {
        let previous = captureChain
        let task = Task { () -> NSImage? in
            await previous?.value
            return await work()
        }
        captureChain = Task { _ = await task.value }
        return await task.value
    }

    // MARK: - Eşleştirme

    /// AX penceresiyle ScreenCaptureKit penceresini eşleştirir.
    ///
    /// İkisi de sol-üst orijinli ekran koordinatı kullandığı için önce konum ve
    /// boyut birebir tutmalı. Minimize pencerelerde çerçeve kayabildiğinden
    /// ikinci deneme: aynı uygulama + aynı başlık.
    private func match(_ window: WindowInfo, in list: [SCWindow]) -> SCWindow? {
        let sameApp = list.filter { $0.owningApplication?.processID == window.pid }

        if let exact = sameApp.first(where: { candidate in
            abs(candidate.frame.origin.x - window.frame.origin.x) < 2 &&
            abs(candidate.frame.origin.y - window.frame.origin.y) < 2 &&
            abs(candidate.frame.width - window.frame.width) < 2 &&
            abs(candidate.frame.height - window.frame.height) < 2
        }) {
            return exact
        }

        guard !window.title.isEmpty else { return nil }
        return sameApp.first { $0.title == window.title }
    }

    /// Aynı anda birden çok hücre önizleme isterse liste **bir kez** çekilir.
    private func shareableWindows() async -> [SCWindow] {
        if let contentTask { return await contentTask.value }

        let task = Task<[SCWindow], Never> {
            guard let content = try? await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            ) else { return [] }
            return content.windows
        }
        contentTask = task
        return await task.value
    }

    private func cacheKey(for window: WindowInfo) -> String {
        "\(window.pid)|\(Int(window.frame.origin.x)),\(Int(window.frame.origin.y))"
            + "|\(Int(window.frame.width))x\(Int(window.frame.height))|\(window.title)"
    }
}
