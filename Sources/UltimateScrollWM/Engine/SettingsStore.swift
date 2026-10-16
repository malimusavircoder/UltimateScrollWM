import Foundation

/// Ayarlar arayüzü ile Paneru'nun `config.toml` dosyası arasındaki köprü.
///
/// Arayüzdeki her anahtar buradan okunur ve yazılır. Yazma anında dosya
/// kaydedilir; Paneru dosyayı canlı yeniden yüklediği için değişiklik anında
/// uygulanır.
///
/// Yol biçimi: `"section.key"` — örn. `"options.focus_follows_mouse"`,
/// `"decorations.active.border.enabled"`. Bölüm adı son noktadan önceki kısımdır.
@MainActor
final class SettingsStore: ObservableObject {

    /// Her okuma/yazma sonrası artar; SwiftUI'nin arayüzü yenilemesini sağlar.
    @Published private(set) var revision = 0
    @Published private(set) var errorMessage: String?

    private(set) var url: URL?
    private var config: PaneruConfig?
    private var isBatching = false

    init() {
        reload()
    }

    /// Dosyayı diskten yeniden okur (dış düzenlemeleri almak için).
    func reload() {
        do {
            let fileURL = try PaneruService.shared.makeConfigFileIfNeeded()
            url = fileURL
            config = try PaneruConfig(contentsOf: fileURL)
            errorMessage = nil
        } catch {
            config = nil
            errorMessage = error.localizedDescription
        }
        revision &+= 1
    }

    // MARK: - Tipli erişim

    func bool(_ path: String, default fallback: Bool) -> Bool {
        guard let value = rawValue(path) else { return fallback }
        return value.lowercased() == "true"
    }

    func setBool(_ path: String, _ value: Bool) {
        write(path, value ? "true" : "false")
    }

    func int(_ path: String, default fallback: Int) -> Int {
        guard let value = rawValue(path), let number = Int(value) else { return fallback }
        return number
    }

    func setInt(_ path: String, _ value: Int) {
        write(path, String(value))
    }

    func double(_ path: String, default fallback: Double) -> Double {
        guard let value = rawValue(path), let number = Double(value) else { return fallback }
        return number
    }

    func setDouble(_ path: String, _ value: Double) {
        write(path, Self.format(value))
    }

    // MARK: - İç işleyiş

    private func rawValue(_ path: String) -> String? {
        guard let (section, key) = Self.split(path) else { return nil }
        return config?.rawValue(section: section, key: key)
    }

    private func write(_ path: String, _ value: String) {
        guard let (section, key) = Self.split(path) else { return }
        config?.set(section: section, key: key, value: value)
        if !isBatching { save() }
    }

    /// Birden çok anahtarı **tek** dosya yazımıyla günceller.
    ///
    /// Kaydırıcı gibi art arda yazan kontroller için gereklidir; aksi hâlde her
    /// anahtar için dosya yeniden yazılır ve paneru gereksiz yere yeniden yükler.
    func batch(_ body: () -> Void) {
        isBatching = true
        body()
        isBatching = false
        save()
    }

    private func save() {
        guard let config, let url else { return }
        do {
            try config.text.write(to: url, atomically: true, encoding: .utf8)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        revision &+= 1
    }

    private static func split(_ path: String) -> (section: String, key: String)? {
        guard let dot = path.lastIndex(of: ".") else { return nil }
        return (String(path[path.startIndex..<dot]), String(path[path.index(after: dot)...]))
    }

    private static func format(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%g", value)
    }
}
