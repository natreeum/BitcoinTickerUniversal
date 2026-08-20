import AppKit
import Foundation

@main
enum BitcoinTickerUninstaller {
    private static let mainBundleIdentifier = "com.local.BitcoinTickerUniversal"
    private static let appURL = URL(fileURLWithPath: "/Applications/Bitcoin Ticker Universal.app")

    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        application.finishLaunching()

        guard confirmUninstall() else { return }

        do {
            try uninstall()
            showResult(
                title: "Uninstall Complete",
                message: "Bitcoin Ticker Universal and its settings were moved or removed successfully."
            )
        } catch {
            showResult(title: "Uninstall Failed", message: error.localizedDescription, isError: true)
        }
    }

    @MainActor
    private static func confirmUninstall() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Uninstall Bitcoin Ticker Universal?"
        let uninstallButton = alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        let monitor = RunningAppMonitor(alert: alert, uninstallButton: uninstallButton)
        monitor.start()
        defer { monitor.stop() }

        return alert.runModal() == .alertFirstButtonReturn
    }

    @MainActor
    private static func uninstall() throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw UninstallError.appNotFound
        }

        try unregisterLoginItem()
        try removeUserData()

        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: appURL, resultingItemURL: &trashedURL)
    }

    private static func unregisterLoginItem() throws {
        let executableURL = appURL
            .appendingPathComponent("Contents/MacOS/BitcoinTickerUniversal")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw UninstallError.missingExecutable
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--unregister-login-item"]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "Unknown login item error"
            throw UninstallError.loginItem(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func removeUserData() throws {
        let fileManager = FileManager.default
        let library = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let urls = [
            library.appendingPathComponent("Preferences/\(mainBundleIdentifier).plist"),
            library.appendingPathComponent("Caches/\(mainBundleIdentifier)"),
            library.appendingPathComponent("Application Support/\(mainBundleIdentifier)"),
            library.appendingPathComponent("Saved Application State/\(mainBundleIdentifier).savedState"),
            library.appendingPathComponent("HTTPStorages/\(mainBundleIdentifier)")
        ]

        UserDefaults.standard.removePersistentDomain(forName: mainBundleIdentifier)
        for url in urls where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    @MainActor
    private static func showResult(title: String, message: String, isError: Bool = false) {
        let alert = NSAlert()
        alert.alertStyle = isError ? .critical : .informational
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

@MainActor
private final class RunningAppMonitor: NSObject {
    private static let mainBundleIdentifier = "com.local.BitcoinTickerUniversal"
    private let alert: NSAlert
    private let uninstallButton: NSButton
    private var timer: Timer?

    init(alert: NSAlert, uninstallButton: NSButton) {
        self.alert = alert
        self.uninstallButton = uninstallButton
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(refresh),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func refresh() {
        let isRunning = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.mainBundleIdentifier
        ).contains(where: { !$0.isTerminated })

        uninstallButton.isEnabled = !isRunning
        alert.informativeText = isRunning
            ? "앱이 실행 중이므로 삭제할 수 없습니다."
            : "The app will be moved to the Trash. Saved price sources, preferences, caches, and login items will be permanently removed."
    }
}

private enum UninstallError: LocalizedError {
    case appNotFound
    case missingExecutable
    case loginItem(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound:
            return "Bitcoin Ticker Universal was not found in /Applications."
        case .missingExecutable:
            return "The installed app executable is missing."
        case .loginItem(let message):
            return "The login item could not be removed: \(message)"
        }
    }
}
