import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

@MainActor
final class MainViewModel: ObservableObject {
    enum OperationState: Equatable {
        case idle
        case working(String)
        case completed(String)
        case failed(String)
    }

    @Published private(set) var authState: GoogleAuthenticator.State
    @Published private(set) var accounts: [GoogleAccount]
    @Published var operationState: OperationState = .idle
    @Published var activeAccountEmail: String?

    private let authenticator: GoogleAuthenticator
    private let fileRouter: FileRouter
    private var cancellables: Set<AnyCancellable> = []

    init(authenticator: GoogleAuthenticator, fileRouter: FileRouter) {
        self.authenticator = authenticator
        self.fileRouter = fileRouter
        self.authState = authenticator.state
        self.accounts = authenticator.accounts

        authenticator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.authState = state
            }
            .store(in: &cancellables)

        authenticator.$accounts
            .receive(on: RunLoop.main)
            .sink { [weak self] accounts in
                self?.accounts = accounts
            }
            .store(in: &cancellables)

        fileRouter.eventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handle(event: event)
            }
            .store(in: &cancellables)
    }

    func signIn() {
        Task {
            do {
                operationState = .working("Connecting to Google Workspace…")
                try await authenticator.signIn()
                operationState = .completed("Connected to Google Workspace")
            } catch {
                operationState = .failed("Sign-in failed: \(error.localizedDescription)")
            }
        }
    }

    func signOut(accountID: String) {
        authenticator.signOut(accountID: accountID)
    }

    func configureFolder(accountID: String) {
        guard let account = authenticator.accounts.first(where: { $0.id == accountID }) else { return }
        let alert = NSAlert()
        alert.messageText = "Preferred Drive Folder"
        alert.informativeText = "Enter a folder name to store uploads for \(account.email). Leave blank to use the default Drive location."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let textField = NSTextField(string: account.preferredFolderName ?? "")
        textField.placeholderString = "Folder name (optional)"
        textField.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = textField
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        authenticator.updatePreferredFolder(accountID: accountID, folderName: trimmed.isEmpty ? nil : trimmed)
    }

    func manualFileSelection() {
        guard accounts.isEmpty == false else {
            operationState = .failed("Connect a Google account first.")
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = SupportedFileKind.acceptedTypes
        panel.canChooseDirectories = false
        panel.prompt = "Upload"

        panel.begin { [weak self] result in
            guard result == .OK else { return }
            let urls = panel.urls
            self?.openFiles(at: urls)
        }
    }

    func openFiles(at urls: [URL]) {
        guard accounts.isEmpty == false else {
            operationState = .failed("Connect a Google account first.")
            return
        }
        Task {
            for url in urls {
                _ = fileRouter.handleFileOpen(url: url)
            }
        }
    }

    private func handle(event: FileRouter.Event) {
        switch event {
        case .started(let description, let account):
            operationState = .working(description)
            activeAccountEmail = account?.email
        case .finished(let description):
            operationState = .completed(description)
            activeAccountEmail = nil
        case .failed(let error):
            if let routerError = error as? FileRouterError, routerError == .userCancelled {
                operationState = .idle
            } else {
                operationState = .failed(error.localizedDescription)
            }
            activeAccountEmail = nil
        }
    }
}
