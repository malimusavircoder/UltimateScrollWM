import SwiftUI
import AppKit

struct WindowSwitcherView: View {
    @ObservedObject var engine: StripEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pencereler")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(visibleIndices, id: \.self) { index in
                    let window = engine.state.windows[index]
                    VStack(spacing: 8) {
                        appIcon(for: window.pid)
                            .frame(width: 48, height: 48)

                        Text(window.appName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)

                        Text(window.title.isEmpty ? "Adsız pencere" : window.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 130, height: 105)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(index == engine.state.focusedIndex
                                  ? Color.accentColor.opacity(0.22)
                                  : Color.primary.opacity(0.06))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(index == engine.state.focusedIndex ? Color.accentColor : .clear, lineWidth: 3)
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .padding(12)
    }

    private var visibleIndices: [Int] {
        let count = engine.state.windows.count
        guard count > 6 else { return Array(0..<count) }
        let start = max(0, min(engine.state.focusedIndex - 2, count - 6))
        return Array(start..<(start + 6))
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
}
