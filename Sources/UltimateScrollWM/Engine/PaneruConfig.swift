import Foundation

/// Paneru'nun TOML yapılandırma dosyası üzerinde çalışan küçük bir düzenleyici.
///
/// Amaç: dosyanın geri kalanını (kullanıcı yorumları, kısayollar, pencere
/// kuralları) **korumak**, yalnızca arayüzün yönettiği anahtarları okuyup
/// yazmak. Paneru dosyayı kaydettiğimizde yapılandırmayı canlı olarak yeniden
/// yükler, yani değişiklikler anında uygulanır.
struct PaneruConfig {

    private var lines: [String]

    init(text: String) {
        lines = text.components(separatedBy: "\n")
    }

    init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        self.init(text: text)
    }

    var text: String { lines.joined(separator: "\n") }

    // MARK: - Okuma

    /// `[section]` içindeki `key` değerini, yorumlar ayıklanmış hâlde döndürür.
    func rawValue(section: String, key: String) -> String? {
        guard let range = contentRange(ofSection: section) else { return nil }
        for index in range {
            if let entry = Self.parseKeyLine(lines[index]), entry.key == key {
                return entry.value
            }
        }
        return nil
    }

    // MARK: - Yazma

    /// Bir anahtarı ayarlar: varsa günceller, yoksa ait olduğu bölüme ekler,
    /// bölüm yoksa en sona yeni bir bölüm açar.
    mutating func set(section: String, key: String, value: String) {
        if let range = contentRange(ofSection: section) {
            for index in range {
                if let entry = Self.parseKeyLine(lines[index]), entry.key == key {
                    lines[index] = "\(key) = \(value)"
                    return
                }
            }
            // Bölümde yok: son dolu satırdan sonra ekle.
            var insertAt = range.lowerBound
            for index in range where !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                insertAt = index + 1
            }
            lines.insert("\(key) = \(value)", at: insertAt)
        } else {
            if let last = lines.last, !last.isEmpty { lines.append("") }
            lines.append("[\(section)]")
            lines.append("\(key) = \(value)")
        }
    }

    // MARK: - Ayrıştırma yardımcıları

    private func headers() -> [(name: String, index: Int)] {
        lines.enumerated().compactMap { index, line in
            guard let name = Self.parseSectionName(line) else { return nil }
            return (name, index)
        }
    }

    private func contentRange(ofSection section: String) -> Range<Int>? {
        let all = headers()
        guard let position = all.firstIndex(where: { $0.name == section }) else { return nil }
        let start = all[position].index + 1
        let end = position + 1 < all.count ? all[position + 1].index : lines.count
        return start..<end
    }

    static func parseSectionName(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "[", !trimmed.hasPrefix("[["),
              let close = trimmed.firstIndex(of: "]") else { return nil }
        let name = trimmed[trimmed.index(after: trimmed.startIndex)..<close]
            .trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    static func parseKeyLine(_ line: String) -> (key: String, value: String)? {
        let content = stripComment(line)
        guard let equals = content.firstIndex(of: "=") else { return nil }
        let key = content[content.startIndex..<equals].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !key.hasPrefix("["), !key.contains(" "), key != "]" else { return nil }
        let value = content[content.index(after: equals)...].trimmingCharacters(in: .whitespaces)
        return (key, value)
    }

    /// Satır sonundaki yorumu (`# ...`) ayıklar; ama metin dizelerinin içindeki
    /// `#` karakterlerine dokunmaz.
    static func stripComment(_ line: String) -> String {
        var result = ""
        var inString = false
        var escaped = false
        for character in line {
            if escaped { result.append(character); escaped = false; continue }
            if character == "\\" && inString { result.append(character); escaped = true; continue }
            if character == "\"" { inString.toggle(); result.append(character); continue }
            if character == "#" && !inString { break }
            result.append(character)
        }
        return result
    }
}
