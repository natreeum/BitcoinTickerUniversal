import AppKit
import Combine
import ServiceManagement
import SwiftUI

@main
enum BitcoinTickerUniversalMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--unregister-login-item") {
            unregisterLoginItem()
            return
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }


    private static func unregisterLoginItem() {
        var didFail = false

        if #available(macOS 13.0, *), SMAppService.mainApp.status == .enabled {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                didFail = true
            }
        }

        let launchAgentURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("com.local.BitcoinTickerUniversal.launcher.plist")
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            do {
                try FileManager.default.removeItem(at: launchAgentURL)
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                didFail = true
            }
        }

        if didFail {
            exit(EXIT_FAILURE)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PriceSourceStore()
    private lazy var ticker = PriceTickerViewModel(store: store)
    private let launchAtLogin = LaunchAtLoginController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.title = ticker.displayPrice
        statusItem.button?.font = .monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize + 1,
            weight: .regular
        )
        statusItem.menu = makeMenu()

        ticker.$displayPrice
            .receive(on: RunLoop.main)
            .sink { [weak self] price in self?.statusItem.button?.title = price }
            .store(in: &cancellables)

        store.$selectedSourceID
            .dropFirst()
            .sink { [weak self] selectedSourceID in
                self?.updateSourceMenuSelection(selectedSourceID)
            }
            .store(in: &cancellables)

        store.$sources
            .dropFirst()
            .sink { [weak self] sources in
                guard let self else { return }
                statusItem.menu = makeMenu(
                    sources: sources,
                    selectedSourceID: store.selectedSourceID
                )
            }
            .store(in: &cancellables)

        ticker.restartPolling()
    }

    private func makeMenu(
        sources: [PriceSource]? = nil,
        selectedSourceID: UUID? = nil
    ) -> NSMenu {
        let sources = sources ?? store.sources
        let selectedSourceID = selectedSourceID ?? store.selectedSourceID
        let menu = NSMenu()

        let sourceListItem = NSMenuItem(title: "Price Source List", action: nil, keyEquivalent: "")
        let sourceMenu = NSMenu()
        for source in sources {
            let item = NSMenuItem(
                title: source.label,
                action: #selector(selectSource(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = source.id
            item.state = source.id == selectedSourceID ? .on : .off
            sourceMenu.addItem(item)
        }
        sourceListItem.submenu = sourceMenu
        menu.addItem(sourceListItem)
        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = launchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit App",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let source = store.sources.first(where: { $0.id == id }) else { return }
        updateSourceMenuSelection(id)
        store.select(source)
    }

    private func updateSourceMenuSelection(_ selectedSourceID: UUID?) {
        guard let sourceMenu = statusItem.menu?
            .item(withTitle: "Price Source List")?
            .submenu else { return }

        for item in sourceMenu.items {
            item.state = item.representedObject as? UUID == selectedSourceID ? .on : .off
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
        sender.state = launchAtLogin.isEnabled ? .on : .off
        if let message = launchAtLogin.errorMessage {
            presentError(message)
        }
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow()
            let controller = NSHostingController(
                rootView: SettingsView(store: store) { [weak window] in
                    window?.close()
                }
            )
            window.contentViewController = controller
            window.title = "Bitcoin Ticker Universal Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 760, height: 460))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Launch at Login"
        alert.informativeText = message
        alert.runModal()
    }
}
