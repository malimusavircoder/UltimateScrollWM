import Foundation
import AppKit

@MainActor
final class PaneruService: ObservableObject {
    static let shared = PaneruService()
    private static let machServiceName = "com.local.UltimateScrollWM.engine"

    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var process: Process?

    private init() {}

    var configURL: URL? {
        try? applicationSupportDirectory().appendingPathComponent("config.toml")
    }

    func start() {
        guard process?.isRunning != true else { return }

        do {
            let binary = try bundledResource(named: "paneru", extension: nil)
            let config = try ensureConfiguration()
            let task = Process()
            task.executableURL = binary
            task.arguments = ["launch"]
            var environment = ProcessInfo.processInfo.environment
            environment["PANERU_CONFIG"] = config.path
            environment["PANERU_MACH_SERVICE"] = Self.machServiceName
            task.environment = environment
            task.standardOutput = FileHandle.nullDevice
            let errorPipe = Pipe()
            task.standardError = errorPipe
            task.terminationHandler = { [weak self] finished in
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8)
                Task { @MainActor in
                    self?.isRunning = false
                    if finished.terminationStatus != 0, let message, !message.isEmpty {
                        self?.lastError = message
                    }
                }
            }
            try task.run()
            process = task
            isRunning = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            isRunning = false
        }
    }

    /// Motoru zarifçe kapatır.
    ///
    /// Önce paneru'nun `quit` komutunu gönderir; böylece paneru kendi temizlik
    /// işini yapıp pencereleri ekranda bırakır (SIGINT ile aniden öldürmek
    /// pencereleri ekran dışında bırakabiliyordu). Kısa süre içinde kapanmazsa
    /// sırasıyla SIGTERM ve SIGINT ile zorlanır.
    ///
    /// Uygulama kapanırken çağrıldığı için kısa bir senkron bekleme kabul edilebilir.
    func stop() {
        guard let process, process.isRunning else {
            self.process = nil
            isRunning = false
            return
        }

        send(["quit"])

        let deadline = Date().addingTimeInterval(1.5)
        while process.isRunning && Date() < deadline {
            usleep(50_000) // 50 ms
        }
        if process.isRunning { process.terminate() }

        self.process = nil
        isRunning = false
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.start() }
    }

    func send(_ arguments: [String]) {
        do {
            let task = Process()
            task.executableURL = try bundledResource(named: "paneru", extension: nil)
            task.arguments = ["send-cmd"] + arguments
            var environment = ProcessInfo.processInfo.environment
            environment["PANERU_MACH_SERVICE"] = Self.machServiceName
            task.environment = environment
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try task.run()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func revealConfiguration() {
        guard let configURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([configURL])
    }

    /// Yapılandırma dosyasının yolunu döndürür; dosya yoksa gömülü
    /// varsayılan yapılandırmadan oluşturur.
    func makeConfigFileIfNeeded() throws -> URL {
        try ensureConfiguration()
    }

    private func ensureConfiguration() throws -> URL {
        let directory = try applicationSupportDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("config.toml")
        if !FileManager.default.fileExists(atPath: destination.path) {
            let source = try bundledResource(named: "default-config", extension: "toml")
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return destination
    }

    private func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("UltimateScrollWM", isDirectory: true)
    }

    private func bundledResource(named name: String, extension fileExtension: String?) throws -> URL {
        let filename = fileExtension.map { "\(name).\($0)" } ?? name
        let installedCandidates = [
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/UltimateScrollWM_UltimateScrollWM.bundle/Resources")
                .appendingPathComponent(filename),
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/UltimateScrollWM_UltimateScrollWM.bundle/Contents/Resources/Resources")
                .appendingPathComponent(filename)
        ]
        if let installed = installedCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return installed
        }
        if let url = Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources")
            ?? Bundle.module.url(forResource: name, withExtension: fileExtension) {
            return url
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
