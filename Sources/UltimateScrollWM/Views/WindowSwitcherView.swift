import SwiftUI
import AppKit

/// `⌥Tab` pencere seçicisinin görünümü.
///
/// Windows'taki `Alt+Tab` gibi davranır: pencereler ızgara hâlinde listelenir,
/// `⌘M` ile simge durumuna küçültülmüş olanlar da **bir işaretle** görünür.
struct WindowSwitcherView: View {
    @ObservedObject var engine: StripEngine

    /// Panel boyutunu hesaplarken denetleyici de bu değerleri kullanır.
    enum Layout {
        static let cellWidth: CGFloat = 132
        static let cellHeight: CGFloat = 118
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
            ZStack(alignment: .bottomTrailing) {
                appIcon(for: window.pid)
                    .frame(width: 44, height: 44)
                    .opacity(window.isMinimized ? 0.5 : 1)

                if window.isMinimized {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 13))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .secondary)
                        .offset(x: 4, y: 4)
                }
            }

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
    }

    @ViewBuilder
    private func appIcon(for pid: pid_t) -> some View {
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
