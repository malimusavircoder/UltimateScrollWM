import AppKit
import SwiftUI

@MainActor
final class WindowSwitcherController {
    private weak var engine: StripEngine?
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    init(engine: StripEngine) {
        self.engine = engine
    }

    func showNext() {
        show(direction: 1)
    }

    func showPrevious() {
        show(direction: -1)
    }

    private func show(direction: Int) {
        guard let engine else { return }
        engine.refreshWindows()
        guard !engine.state.windows.isEmpty else { return }

        if direction > 0 {
            engine.selectNextForSwitcher()
        } else {
            engine.selectPreviousForSwitcher()
        }

        present(engine: engine)
        scheduleCommit()
    }

    private func present(engine: StripEngine) {
        let visibleCount = min(engine.state.windows.count, 6)
        let width = CGFloat(visibleCount * 156 + 36)
        let height: CGFloat = 165

        if panel == nil {
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.level = .statusBar
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            panel = newPanel
        }

        panel?.setContentSize(NSSize(width: width, height: height))
        panel?.contentView = NSHostingView(rootView: WindowSwitcherView(engine: engine))

        if let screen = NSScreen.main, let panel {
            panel.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - panel.frame.width / 2,
                y: screen.visibleFrame.midY - panel.frame.height / 2
            ))
        }
        panel?.orderFrontRegardless()
    }

    private func scheduleCommit() {
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.engine?.activateSwitcherSelection()
            self.panel?.orderOut(nil)
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: workItem)
    }
}
