import SwiftUI
import AppKit

/// `⌥Tab` pencere seçicisinin görünümü.
///
/// Windows'taki `Alt+Tab` gibi davranır: pencereler ızgara hâlinde listelenir,
/// `⌘M` ile simge durumuna küçültülmüş olanlar da **bir işaretle** görünür.
///
/// İki ek özellik:
///   * Her hücrede gerçek pencere görüntüsü (Ekran Kaydı izni varsa).
///   * Her hücrenin köşesinde pencereyi kapatan `✕` düğmesi.
struct WindowSwitcherView: View {
    @ObservedObject var engine: StripEngine

    /// `✕` tıklandığında denetleyiciye haber verilir; böylece panel yeni
    /// pencere sayısına göre yeniden boyutlanabilir.
    var onClose: ((Int) -> Void)?

    /// Panel boyutunu hesaplarken denetleyici de bu değerleri kullanır.
    enum Layout {
        static let cellWidth: CGFloat = 150
        static let cellHeight: CGFloat = 134
        static let previewWidth: CGFloat = 122
        static let previewHeight: CGFloat = 72
        static let spacing: CGFloat = 10
        static let padding: CGFloat = 18
        static let maxColumns = 5
        static let maxVisible = 20
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            LazyVGrid(columns: gridColumns, spacing: Layout.spacing) {
                ForEach(visibleIndices, id: \.self) { index in
                    cell(index: index)
                }
            }

            footer
        }
        .padding(Layout.padding)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .padding(12)
    }

    // MARK: - Parçalar

    private var header: some View {
        HStack(spacing: 8) {
            Text("Pencereler")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(pagingText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Label("bırakınca seç", systemImage: "option")
            Label("Tab ile gez", systemImage: "arrow.left.arrow.right")
            Label("Esc iptal", systemImage: "escape")
            Label("kapat", systemImage: "xmark.circle")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }

    @ViewBuilder
    private func cell(index: Int) -> some View {
        let window = engine.state.windows[index]
        let selected = index == engine.state.focusedIndex

        VStack(spacing: 6) {
            WindowPreview(window: window, size: previewSize)

            Text(window.appName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Text(window.title.isEmpty ? "Adsız pencere" : window.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: Layout.cellWidth, height: Layout.cellHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Color.accentColor : .clear, lineWidth: 3)
        }
        .overlay(alignment: .topTrailing) {
            closeButton(index: index)
                .padding(5)
        }
    }

    /// Pencerenin kapatma (`✕`) düğmesi.
    private func closeButton(index: Int) -> some View {
        Button {
            close(at: index)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.black.opacity(0.55)))
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Pencereyi kapat")
    }

    private func close(at index: Int) {
        if let onClose {
            onClose(index)
        } else {
            engine.closeSwitcherWindow(at: index)
        }
    }

    private var previewSize: CGSize {
        CGSize(width: Layout.previewWidth, height: Layout.previewHeight)
    }

    // MARK: - Hesaplar

    /// Kaç sütun gösterilecek (pencere sayısı azsa daraltılır).
    private var columns: Int {
        min(Layout.maxColumns, max(1, engine.state.windows.count))
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(Layout.cellWidth), spacing: Layout.spacing),
            count: columns
        )
    }

    /// Gösterilen pencere aralığı. 20'den fazla pencere varsa, seçimi içeren
    /// "sayfa" gösterilir.
    private var visibleIndices: [Int] {
        let count = engine.state.windows.count
        guard count > Layout.maxVisible else { return Array(0..<count) }

        let page = engine.state.focusedIndex / Layout.maxVisible
        let start = page * Layout.maxVisible
        return Array(start..<min(start + Layout.maxVisible, count))
    }

    private var pagingText: String {
        let total = engine.state.windows.count
        guard total > Layout.maxVisible else { return "\(total) pencere" }

        let page = engine.state.focusedIndex / Layout.maxVisible + 1
        let pageCount = (total + Layout.maxVisible - 1) / Layout.maxVisible
        return "\(total) pencere · \(page)/\(pageCount)"
    }
}

/// Hücre içindeki pencere görüntüsü.
///
/// Önizleme alınamıyorsa (Ekran Kaydı izni yok ya da pencere yakalanamadı)
/// sessizce uygulama simgesine düşer — seçici hiçbir durumda bozulmaz.
private struct WindowPreview: View {
    let window: WindowInfo
    let size: CGSize

    @State private var image: NSImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                AppIcon(pid: window.pid)
                    .frame(width: 40, height: 40)
            }

            if window.isMinimized {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 13))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .secondary)
                    .offset(x: 4, y: 4)
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: taskID) {
            image = await WindowThumbnailProvider.shared.thumbnail(for: window, size: size)
        }
    }

    /// Aynı pencere için tekrar tekrar yakalama yapılmasın.
    private var taskID: String {
        "\(window.pid)|\(window.title)|\(Int(window.frame.width))x\(Int(window.frame.height))"
    }
}

/// Uygulama simgesi (önizleme yokken kullanılır).
private struct AppIcon: View {
    let pid: pid_t

    var body: some View {
        if let icon = NSRunningApplication(processIdentifier: pid)?.icon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "macwindow")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }
}
