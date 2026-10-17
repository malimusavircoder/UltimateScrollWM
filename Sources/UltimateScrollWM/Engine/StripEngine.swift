import Foundation
import AppKit
import ApplicationServices

/// Core engine that manages the horizontal strip of windows
@MainActor
final class StripEngine: ObservableObject {
    static let shared = StripEngine()
    
    @Published var state = StripState()
    @Published var isEnabled: Bool = true
    @Published var hasPermission: Bool = false
    
    private let accessibility = AccessibilityManager.shared
    /// Olay bildirimleri kısa sürede ardı ardına gelir; tek tazelemede birleştirilir.
    private var pendingRefresh: DispatchWorkItem?
    private var screenFrame: CGRect = .zero
    private var isStarted = false
    private let widthPresets: [CGFloat] = [0.5, 2.0 / 3.0, 1.0]
    var managesLayout = false
    
    // MARK: - Lifecycle
    
    func start() {
        guard !isStarted else { return }
        isStarted = true
        checkPermission()
        
        guard hasPermission else {
            isStarted = false
            return
        }
        
        updateScreenFrame()
        refreshWindows()
        applyLayout()

        // Neden sürekli yoklama YOK?
        // Pencere düzenini paneru yapıyor (`managesLayout = false`), dolayısıyla
        // bu motorun pencere listesi yalnızca arayüzü besler (menü çubuğundaki
        // pencere sayısı, seçici). Eskiden 0.8 sn'de bir TÜM uygulamaların
        // pencereleri Erişilebilirlik API'siyle taranıyordu; bu boşuna CPU ve
        // pil harcıyordu. Artık yalnızca gerçekten bir şey değiştiğinde
        // tazeliyoruz.
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
        ] {
            center.addObserver(self, selector: #selector(workspaceChanged), name: name, object: nil)
        }
    }
    
    func stop() {
        pendingRefresh?.cancel()
        pendingRefresh = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        isStarted = false
    }
    
    // MARK: - Permission
    
    func checkPermission() {
        hasPermission = accessibility.checkPermission()
    }
    
    func requestPermission() {
        accessibility.requestPermission()
        // User needs to grant it in System Settings, then we re-check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkPermission()
            if self.hasPermission {
                self.start()
            }
        }
    }
    
    // MARK: - Core Logic
    
    private func updateScreenFrame() {
        // For MVP we use the main screen. Multi-monitor comes later.
        if let screen = NSScreen.main {
            screenFrame = screen.visibleFrame
        }
    }
    
    func refreshWindows() {
        guard isEnabled && hasPermission else { return }

        // Pencere seçici açıkken listeyi/seçimi DEĞİŞTİRME: seçici kendi anlık
        // görüntüsüyle çalışır. Aksi hâlde araya giren bir tazeleme (menü
        // açılışı, çalışma alanı olayı) seçimi gerçek odaktaki pencereye geri
        // sıfırlar ve ⌥Tab yalnızca iki pencere arasında gidip gelir.
        guard !isSwitcherSessionActive else { return }
        
        let focusedElement = accessibility.focusedWindow()
        let currentWindows = accessibility.getAllWindows()
        
        // Simple approach for MVP: rebuild the list while trying to keep order
        var newList: [WindowInfo] = []
        
        // Keep existing windows that still exist
        for existing in state.windows {
            if let updated = currentWindows.first(where: { CFEqual($0.id, existing.id) }) {
                var kept = existing
                kept.frame = updated.frame
                kept.title = updated.title
                newList.append(kept)
            }
        }
        
        if let focusedElement,
           let focusedIndex = newList.firstIndex(where: { CFEqual($0.id, focusedElement) }) {
            state.focusedIndex = focusedIndex
        }

        // Add brand new windows next to the focused window.
        for window in currentWindows {
            if !newList.contains(where: { CFEqual($0.id, window.id) }) {
                let insertionIndex = min(state.focusedIndex + 1, newList.count)
                newList.insert(window, at: insertionIndex)
                state.focusedIndex = insertionIndex
            }
        }
        
        // Update indices
        for i in newList.indices {
            newList[i].columnIndex = i
        }
        
        state.windows = newList
        
        if state.focusedIndex >= state.windows.count {
            state.focusedIndex = max(0, state.windows.count - 1)
        }
        
        applyLayout()
    }
    
    func applyLayout() {
        guard managesLayout else { return }
        guard isEnabled, !state.windows.isEmpty else { return }
        
        updateScreenFrame()
        
        let gap = state.gap
        let availableWidth = screenFrame.width
        let defaultWidth = availableWidth * state.defaultWidthRatio
        
        var currentX = screenFrame.minX - state.scrollOffset
        
        for (index, var window) in state.windows.enumerated() {
            let width = window.preferredWidth > 0 ? window.preferredWidth : defaultWidth
            let height = screenFrame.height
            
            let targetFrame = CGRect(
                x: currentX,
                y: screenFrame.minY,
                width: width,
                height: height
            )
            
            accessibility.setFrame(of: window.id, to: targetFrame)
            window.frame = targetFrame
            state.windows[index] = window
            
            currentX += width + gap
        }
        
        adjustScrollOffsetForFocusedWindow()
    }
    
    private func adjustScrollOffsetForFocusedWindow() {
        guard let focused = state.focusedWindow else { return }
        
        let windowLeft = focused.frame.minX
        let windowRight = focused.frame.maxX
        let screenLeft = screenFrame.minX
        let screenRight = screenFrame.maxX
        
        if windowLeft < screenLeft {
            state.scrollOffset -= (screenLeft - windowLeft)
            layoutWithoutAdjustment()
        } else if windowRight > screenRight {
            state.scrollOffset += (windowRight - screenRight)
            layoutWithoutAdjustment()
        }
    }

    private func layoutWithoutAdjustment() {
        var currentX = screenFrame.minX - state.scrollOffset
        for index in state.windows.indices {
            let width = state.windows[index].preferredWidth > 0
                ? state.windows[index].preferredWidth
                : screenFrame.width * state.defaultWidthRatio
            let frame = CGRect(x: currentX, y: screenFrame.minY, width: width, height: screenFrame.height)
            accessibility.setFrame(of: state.windows[index].id, to: frame)
            state.windows[index].frame = frame
            currentX += width + state.gap
        }
    }
    
    // MARK: - Navigation
    
    func focusNext() {
        state.focusNext()
        if let focused = state.focusedWindow {
            accessibility.raiseWindow(focused.id)
        }
        applyLayout()
    }
    
    func focusPrevious() {
        state.focusPrevious()
        if let focused = state.focusedWindow {
            accessibility.raiseWindow(focused.id)
        }
        applyLayout()
    }

    // MARK: - Pencere seçici (⌥Tab)

    private(set) var isSwitcherSessionActive = false

    /// Seçici oturumunu başlatır ve pencere listesinin **tek seferlik anlık
    /// görüntüsünü** alır (minimize pencereler dahil).
    ///
    /// - Returns: Oturum gerçekten açıldıysa `true`. Liste boşsa `false` döner ve
    ///   oturum bayrağı **açılmaz**.
    ///
    /// Neden bayrak sonradan açılıyor: `refreshWindows()` oturum sırasında
    /// çalışmayı reddeder (`guard !isSwitcherSessionActive`). Bayrak, liste boş
    /// olduğu için panel açılmadan kalırsa hiçbir zaman kapanmaz ve pencere
    /// listesi uygulama yeniden başlatılana kadar donar. Ekran kilitliyken veya
    /// uyku sonrası ilk saniyelerde AX listesi boş dönebildiği için bu gerçekten
    /// oluyordu.
    @discardableResult
    func beginSwitcherSession() -> Bool {
        guard isEnabled && hasPermission else { return false }

        var list = accessibility.getAllWindows(includeMinimized: true)

        // Boş liste: panel açmanın anlamı yok, oturum da açılmaz.
        // Yine de teşhis kaydı bırak (neden boş olduğunu sonra görebilelim).
        guard !list.isEmpty else {
            Diagnostics.dumpSwitcherWindows(list)
            return false
        }

        isSwitcherSessionActive = true

        for index in list.indices {
            list[index].columnIndex = index
        }
        state.windows = list

        // Seçimi, hâlihazırda odaktaki pencereye getir.
        if let focused = accessibility.focusedWindow(),
           let index = list.firstIndex(where: { CFEqual($0.id, focused) }) {
            state.focusedIndex = index
        } else {
            state.focusedIndex = min(state.focusedIndex, list.count - 1)
        }

        Diagnostics.dumpSwitcherWindows(list)
        return true
    }

    func endSwitcherSession() {
        isSwitcherSessionActive = false
    }

    func selectNextForSwitcher() {
        state.focusNext()
    }

    func selectPreviousForSwitcher() {
        state.focusPrevious()
    }

    func activateSwitcherSelection() {
        guard let focused = state.focusedWindow else { return }
        accessibility.raiseWindow(focused.id)
    }

    /// Seçicideki bir pencereyi kapatır ve listeyi hemen günceller.
    ///
    /// Kapatma AX üzerinden asenkron işler; pencere birazdan kaybolur ama
    /// kullanıcı beklemesin diye listeden **anında** düşürülür.
    func closeSwitcherWindow(at index: Int) {
        guard state.windows.indices.contains(index) else { return }
        let window = state.windows[index]
        _ = accessibility.closeWindow(window.id)

        state.windows.remove(at: index)
        guard !state.windows.isEmpty else {
            state.focusedIndex = 0
            return
        }
        if state.focusedIndex >= state.windows.count {
            state.focusedIndex = state.windows.count - 1
        }
        for i in state.windows.indices {
            state.windows[i].columnIndex = i
        }
    }

    func moveFocusedNext() {
        state.moveFocused(by: 1)
        applyLayout()
    }

    func moveFocusedPrevious() {
        state.moveFocused(by: -1)
        applyLayout()
    }

    func cycleFocusedWidth() {
        guard state.windows.indices.contains(state.focusedIndex) else { return }
        let current = state.windows[state.focusedIndex].preferredWidth / max(screenFrame.width, 1)
        let nextRatio = widthPresets.first(where: { $0 > current + 0.01 }) ?? widthPresets[0]
        state.windows[state.focusedIndex].preferredWidth = screenFrame.width * nextRatio
        applyLayout()
    }

    func makeFocusedFullWidth() {
        guard state.windows.indices.contains(state.focusedIndex) else { return }
        state.windows[state.focusedIndex].preferredWidth = screenFrame.width
        applyLayout()
    }

    func centerFocused() {
        guard let focused = state.focusedWindow else { return }
        state.scrollOffset += focused.frame.midX - screenFrame.midX
        applyLayout()
    }
    
    func toggleEnabled() {
        isEnabled.toggle()
        if isEnabled {
            refreshWindows()
        }
    }
    
    // MARK: - Olaylar
    
    /// Çalışma alanı olaylarında pencere listesini tazeler.
    ///
    /// Bildirimler kısa sürede ardı ardına gelebilir (ör. bir uygulama
    /// açılırken hem `launch` hem `activate` gelir); bu yüzden hepsi tek bir
    /// tazelemede birleştirilir.
    @objc private func workspaceChanged() {
        pendingRefresh?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refreshWindows() }
        pendingRefresh = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
}
