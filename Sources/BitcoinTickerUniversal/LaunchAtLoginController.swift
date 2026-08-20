import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var errorMessage: String?

    private let fileManager = FileManager.default
    private let agentIdentifier = "com.local.BitcoinTickerUniversal.launcher"

    init() {
        migrateLegacyRegistrationIfNeeded()
        refreshStatus()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if #available(macOS 13.0, *) {
                if enabled {
                    try requireAppBundle()
                    try SMAppService.mainApp.register()
                    try removeLaunchAgent()
                } else {
                    try SMAppService.mainApp.unregister()
                    try removeLaunchAgent()
                }
            } else {
                if enabled {
                    try installLaunchAgent()
                } else {
                    try removeLaunchAgent()
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshStatus()
    }

    private func refreshStatus() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        } else {
            isEnabled = fileManager.fileExists(atPath: launchAgentURL.path)
        }
    }

    private func migrateLegacyRegistrationIfNeeded() {
        guard #available(macOS 13.0, *),
              fileManager.fileExists(atPath: launchAgentURL.path),
              Bundle.main.bundleURL.pathExtension == "app" else { return }

        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
            try removeLaunchAgent()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requireAppBundle() throws {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            throw LaunchAtLoginError.requiresAppBundle
        }
    }

    private var launchAgentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentIdentifier).plist")
    }

    private func installLaunchAgent() throws {
        let directory = launchAgentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let executableURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let propertyList: [String: Any] = [
            "Label": agentIdentifier,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    private func removeLaunchAgent() throws {
        guard fileManager.fileExists(atPath: launchAgentURL.path) else { return }
        try fileManager.removeItem(at: launchAgentURL)
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case requiresAppBundle

    var errorDescription: String? {
        "Launch at Login requires running Bitcoin Ticker Universal from its .app bundle."
    }
}
