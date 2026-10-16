import SwiftUI

private enum SettingsPage: String, CaseIterable, Identifiable {
    case home = "Genel Bakış"
    case layout = "Pencere Düzeni"
    case shortcuts = "Kısayollar"
    case advanced = "Gelişmiş"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home: return "sparkles"
        case .layout: return "rectangle.split.3x1"
        case .shortcuts: return "keyboard"
        case .advanced: return "gearshape.2"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var engine: StripEngine
    @ObservedObject var backend: PaneruService
    @StateObject private var loginItem = LoginItemManager()
    @State private var page: SettingsPage? = .home

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $page) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationTitle("UltimateScroll")
            .safeAreaInset(edge: .bottom) { statusBadge.padding(12) }
        } detail: {
            ScrollView {
                Group {
                    switch page ?? .home {
                    case .home: HomeSettings(engine: engine, backend: backend, loginItem: loginItem)
                    case .layout: LayoutSettings(engine: engine, backend: backend)
                    case .shortcuts: ShortcutSettings()
                    case .advanced: AdvancedSettings(backend: backend)
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(32)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }

    private var statusBadge: some View {
        HStack(spacing: 9) {
            Circle().fill(backend.isRunning ? Color.green : Color.orange).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(backend.isRunning ? "Motor çalışıyor" : "Motor duraklatıldı").font(.caption.bold())
                Text("\(engine.state.windows.count) pencere görüldü").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct HomeSettings: View {
    @ObservedObject var engine: StripEngine
    @ObservedObject var backend: PaneruService
    @ObservedObject var loginItem: LoginItemManager

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsHeader(title: "Pencerelerin, düzenli bir şeritte.", subtitle: "Her pencere kendi boyutunu korur. Odağı değiştirince bütün şerit seninle kayar.")
            HStack(spacing: 14) {
                SummaryCard(value: backend.isRunning ? "Aktif" : "Kapalı", label: "Pencere motoru", icon: "checkmark.circle.fill", color: .green)
                SummaryCard(value: "\(engine.state.windows.count)", label: "Yönetilen pencere", icon: "macwindow.on.rectangle", color: .blue)
                SummaryCard(value: "4 parmak", label: "Trackpad hareketi", icon: "hand.draw.fill", color: .purple)
            }
            GroupBox {
                VStack(spacing: 0) {
                    SettingsToggleRow(title: "Pencere yöneticisi", detail: "Yeni pencereleri odaktaki pencerenin yanına yerleştirir", isOn: Binding(get: { backend.isRunning }, set: { $0 ? backend.start() : backend.stop() }))
                    Divider()
                    SettingsToggleRow(title: "Mac açılınca başlat", detail: "Çalışma düzenin giriş yaptığında hazır olsun", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
                }
            }
            Text("Hızlı dene").font(.title3.bold())
            HStack(spacing: 10) {
                CommandButton(title: "Sola git", icon: "arrow.left", command: ["window", "focus", "west"], backend: backend)
                CommandButton(title: "Sağa git", icon: "arrow.right", command: ["window", "focus", "east"], backend: backend)
                CommandButton(title: "Genişlik", icon: "arrow.left.and.right", command: ["window", "resize"], backend: backend)
                CommandButton(title: "Ortala", icon: "rectangle.center.inset.filled", command: ["window", "center"], backend: backend)
            }
            GroupBox("Başlangıç için 5 kısayol") {
                VStack(spacing: 0) {
                    ShortcutRow(title: "Pencereler arasında geç", keys: "⌃⌥ ← / →")
                    Divider(); ShortcutRow(title: "Pencereyi taşı", keys: "⌃⌥⇧ ← / →")
                    Divider(); ShortcutRow(title: "Genişliği değiştir", keys: "⌃⌥ R")
                    Divider(); ShortcutRow(title: "Ekranı doldur", keys: "⌃⌥ F")
                    Divider(); ShortcutRow(title: "Ortaya getir", keys: "⌃⌥ C")
                }
            }
        }
    }
}

private struct LayoutSettings: View {
    @ObservedObject var engine: StripEngine
    @ObservedObject var backend: PaneruService
    @AppStorage("focusBorder") private var focusBorder = true
    @AppStorage("dimInactive") private var dimInactive = true
    @AppStorage("stripMinimap") private var stripMinimap = true
    @AppStorage("fourFingerSwipe") private var fourFingerSwipe = true

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsHeader(title: "Pencere Düzeni", subtitle: "Şeridin görünüşünü ve pencerelerin nasıl davranacağını ayarla.")
            GroupBox("Boyut ve boşluk") {
                VStack(spacing: 18) {
                    HStack {
                        Text("Pencereler arası boşluk")
                        Spacer()
                        Slider(value: gap, in: 0...24, step: 1).frame(width: 240)
                        Text("\(Int(engine.state.gap)) px").monospacedDigit().frame(width: 45)
                    }
                    Toggle("Odaktaki pencereyi renkli çerçeveyle göster", isOn: $focusBorder)
                    Toggle("Pasif pencereleri hafifçe karart", isOn: $dimInactive)
                    Toggle("Gezinirken şerit minimap'ini göster", isOn: $stripMinimap)
                    Toggle("Dört parmakla şeritte kaydır", isOn: $fourFingerSwipe)
                }.padding(10)
            }
            GroupBox("Sütunlar") {
                HStack(spacing: 10) {
                    CommandButton(title: "Stack", icon: "square.stack.3d.up", command: ["window", "stack"], backend: backend)
                    CommandButton(title: "Dışarı çıkar", icon: "square.stack.3d.down.right", command: ["window", "unstack"], backend: backend)
                    CommandButton(title: "Sekmeli yap", icon: "rectangle.stack", command: ["window", "tabbeddisplay"], backend: backend)
                    CommandButton(title: "Eşitle", icon: "equal.square", command: ["window", "equalize"], backend: backend)
                }.padding(8)
            }
        }
    }

    private var gap: Binding<Double> {
        Binding(get: { Double(engine.state.gap) }, set: { engine.state.gap = CGFloat($0); engine.applyLayout() })
    }
}

private struct ShortcutSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsHeader(title: "Kısayollar", subtitle: "Kontrol + Option ile pencere şeridini klavyeden yönet.")
            GroupBox {
                VStack(spacing: 0) {
                    ShortcutRow(title: "Sola / sağa odaklan", keys: "⌃⌥ ← / →")
                    Divider(); ShortcutRow(title: "Pencereyi sola / sağa taşı", keys: "⌃⌥⇧ ← / →")
                    Divider(); ShortcutRow(title: "Genişliği değiştir", keys: "⌃⌥ R")
                    Divider(); ShortcutRow(title: "Tam genişlik", keys: "⌃⌥ F")
                    Divider(); ShortcutRow(title: "Ortala", keys: "⌃⌥ C")
                    Divider(); ShortcutRow(title: "Stack / dışarı çıkar", keys: "⌃⌥ ] / ⇧]")
                    Divider(); ShortcutRow(title: "Sonraki ekrana gönder", keys: "⌃⌥ N")
                }
            }
            Label("Kısayollar Paneru motoru tarafından doğrudan yakalanır; bu yüzden pencere geçişleri gecikmeden başlar.", systemImage: "bolt.fill")
                .foregroundStyle(.secondary)
        }
    }
}

private struct AdvancedSettings: View {
    @ObservedObject var backend: PaneruService
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsHeader(title: "Gelişmiş", subtitle: "Motoru yönet ve yapılandırmayı incele.")
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    Button("Motoru yeniden başlat") { backend.restart() }
                    Button("Yapılandırmayı Finder'da göster") { backend.revealConfiguration() }
                    Text("UltimateScrollWM 0.4 • Paneru 0.5.2 motoru").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            if let error = backend.lastError { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
        }
    }
}

private struct SettingsHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 30, weight: .bold, design: .rounded))
            Text(subtitle).font(.title3).foregroundStyle(.secondary)
        }
    }
}

private struct SummaryCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading) { Text(value).font(.headline); Text(label).font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }.padding(14).frame(maxWidth: .infinity).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer(); Toggle("", isOn: $isOn).labelsHidden()
        }.padding(12)
    }
}

private struct ShortcutRow: View {
    let title: String
    let keys: String
    var body: some View {
        HStack { Text(title); Spacer(); Text(keys).font(.system(.body, design: .monospaced).bold()).foregroundStyle(.secondary) }.padding(12)
    }
}

private struct CommandButton: View {
    let title: String
    let icon: String
    let command: [String]
    @ObservedObject var backend: PaneruService
    var body: some View {
        Button { backend.send(command) } label: { Label(title, systemImage: icon).frame(maxWidth: .infinity) }
            .buttonStyle(.bordered).controlSize(.large)
    }
}
