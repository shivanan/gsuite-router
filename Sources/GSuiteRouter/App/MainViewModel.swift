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
    @Published private(set) var userEmail: String?
    @Published var operationState: OperationState = .idle

    private let authenticator: GoogleAuthenticator
    private let fileRouter: FileRouter
    private var cancellables: Set<AnyCancellable> = []

    init(authenticator: GoogleAuthenticator, fileRouter: FileRouter) {
        self.authenticator = authenticator
        self.fileRouter = fileRouter
        self.authState = authenticator.state
        self.userEmail = authenticator.userEmail

        authenticator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.authState = state
            }
            .store(in: &cancellables)

        authenticator.$userEmail
            .receive(on: RunLoop.main)
            .sink { [weak self] email in
                self?.userEmail = email
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

    func signOut() {
        authenticator.signOut()
        operationState = .idle
    }

    func manualFileSelection() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = SupportedFileKind.acceptedTypes
        panel.canChooseDirectories = false
        panel.prompt = "Upload"

        panel.begin { [weak self] result in
            guard result == .OK else { return }
            let urls = panel.urls
            Task {
                for url in urls {
                    _ = self?.fileRouter.handleFileOpen(url: url)
                }
            }
        }
    }

    private func handle(event: FileRouter.Event) {
        switch event {
        case .started(let description):
            operationState = .working(description)
        case .finished(let description):
            operationState = .completed(description)
        case .failed(let error):
            operationState = .failed(error.localizedDescription)
        }
    }
}
