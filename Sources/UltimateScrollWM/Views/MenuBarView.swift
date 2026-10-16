import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var engine: StripEngine
    @ObservedObject var backend: PaneruService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            if !engine.hasPermission {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Accessibility izni gerekli")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Pencereleri hareket ettirebilmem için Sistem Ayarları’ndan izin vermen gerekiyor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("İzin İste") {
                        engine.requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Sistem Ayarlarını Aç") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Toggle("Aktif", isOn: Binding(
                    get: { backend.isRunning },
                    set: { $0 ? backend.start() : backend.stop() }
                ))
                
                HStack {
                    Text("Pencere")
                    Spacer()
                    Text("\(engine.state.windows.count)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                
                if let focused = engine.state.focusedWindow {
                    HStack {
                        Text("Odak")
                        Spacer()
                        Text(focused.appName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("⌥ Tab   Pencere seçici")
                    Text("⌃⌥ ←   Önceki pencere")
                    Text("⌃⌥ →   Sonraki pencere")
                    Text("⌃⌥⇧ ←/→   Pencereyi taşı")
                    Text("⌃⌥ R   Genişliği değiştir")
                    Text("⌃⌥ F   Tam genişlik")
                    Text("⌃⌥ C   Ortala")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Divider()
            
            Button("Pencereleri Yenile") {
                engine.refreshWindows()
            }

            Menu("Pencere İşlemleri") {
                Button("Floating / tiled") { backend.send(["window", "manage"]) }
                Button("Sola stack") { backend.send(["window", "stack"]) }
                Button("Stack'ten çıkar") { backend.send(["window", "unstack"]) }
                Button("Stack'i tab yap") { backend.send(["window", "tabbeddisplay"]) }
                Button("Yükseklikleri eşitle") { backend.send(["window", "equalize"]) }
                Button("Sonraki ekrana gönder") { backend.send(["window", "nextdisplay"]) }
            }

            Button("Yapılandırma Dosyasını Göster") {
                backend.revealConfiguration()
            }

            if let error = backend.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
            
            Button("Ayarlar…") {
                (NSApp.delegate as? AppDelegate)?.showSettings()
            }
            
            Divider()
            
            Button("Çıkış") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
    
    private var statusText: String {
        if !engine.hasPermission { return "İzin bekleniyor" }
        return backend.isRunning ? "Aktif" : "Duraklatıldı"
    }
    
    private var statusColor: Color {
        if !engine.hasPermission { return .orange }
        return backend.isRunning ? .green : .red
    }
}
