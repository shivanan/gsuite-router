import AppKit
import Combine
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private let authenticator = GoogleAuthenticator()
    private lazy var driveUploader = DriveUploader(authenticator: authenticator)
    private lazy var accountSelector = AccountSelector(authenticator: authenticator)
    private lazy var fileRouter = FileRouter(driveUploader: driveUploader, accountSelector: accountSelector)
    private lazy var viewModel = MainViewModel(authenticator: authenticator, fileRouter: fileRouter)
    private var cancellables: Set<AnyCancellable> = []
    private var shouldTerminateAfterProcessing: Bool = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleAppleEventOpenDocuments(event:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        mainWindowController = MainWindowController(viewModel: viewModel)
        mainWindowController?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        authenticator.restore()
        observeFileRouting()
        processLaunchArguments()
    }

    @objc private func handleAppleEventOpenDocuments(event: NSAppleEventDescriptor, withReply replyEvent: NSAppleEventDescriptor?) {
        guard let list = event.paramDescriptor(forKeyword: keyDirectObject) else { return }
        var urls: [URL] = []
        for index in 1...list.numberOfItems {
            if let path = list.atIndex(index)?.stringValue {
                urls.append(urlFromDockPath(path))
            }
        }
        guard urls.isEmpty == false else { return }
        urls.forEach { _ = fileRouter.handleFileOpen(url: $0) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag == false {
            mainWindowController?.showWindow(self)
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = urlFromDockPath(filename)
        return fileRouter.handleFileOpen(url: url)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        filenames.forEach { _ = fileRouter.handleFileOpen(url: urlFromDockPath($0)) }
        NSApp.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { _ = fileRouter.handleFileOpen(url: $0) }
        NSApp.reply(toOpenOrPrint: .success)
    }

    private func processLaunchArguments() {
        let args = CommandLine.arguments.dropFirst()
        guard args.isEmpty == false else { return }
        shouldTerminateAfterProcessing = true
        args.forEach { argument in
            let url = urlFromDockPath(argument)
            _ = fileRouter.handleFileOpen(url: url)
        }
    }

    private func configureMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About GSuite Router", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit GSuite Router", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu

        NSApplication.shared.mainMenu = mainMenu
    }

    private func observeFileRouting() {
        fileRouter.eventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handleFileRouter(event)
            }
            .store(in: &cancellables)
    }

    private func handleFileRouter(_ event: FileRouter.Event) {
        guard shouldTerminateAfterProcessing else { return }
        switch event {
        case .finished:
            shouldTerminateAfterProcessing = false
            NSApp.terminate(self)
        case .failed:
            shouldTerminateAfterProcessing = false
        case .started:
            break
        }
    }

    private func urlFromDockPath(_ path: String) -> URL {
        if let candidate = URL(string: path), candidate.scheme?.lowercased() == "file" {
            return candidate.standardizedFileURL
        }
        let decoded = path.removingPercentEncoding ?? path
        return URL(fileURLWithPath: decoded)
    }
}
