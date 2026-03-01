import AppKit

@MainActor
final class AccountSelector {
    enum SelectionError: Error {
        case noAccounts
        case userCancelled
    }

    private let authenticator: GoogleAuthenticator

    init(authenticator: GoogleAuthenticator) {
        self.authenticator = authenticator
    }

    func selectAccount(for fileURL: URL) async throws -> GoogleAccount {
        let accounts = authenticator.accounts
        guard !accounts.isEmpty else {
            throw SelectionError.noAccounts
        }
        if accounts.count == 1, let first = accounts.first {
            return first
        }
        return try await withCheckedThrowingContinuation { continuation in
            let action: @MainActor () -> Void = {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "Pick an account"
                alert.informativeText = "Choose which Google account should handle \(fileURL.lastPathComponent)."
                alert.addButton(withTitle: "Use Account")
                alert.addButton(withTitle: "Cancel")
                let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 26), pullsDown: false)
                popup.addItems(withTitles: accounts.map { $0.email })
                alert.accessoryView = popup
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    let selectedIndex = popup.indexOfSelectedItem
                    continuation.resume(returning: accounts[selectedIndex])
                } else {
                    continuation.resume(throwing: SelectionError.userCancelled)
                }
            }
            Task { @MainActor in action() }
        }
    }
}
