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
        return try await AccountSelectionPrompt.prompt(accounts: accounts, fileName: fileURL.lastPathComponent)
    }
}

private enum AccountSelectionPrompt {
    static func prompt(accounts: [GoogleAccount], fileName: String) async throws -> GoogleAccount {
        try await withCheckedThrowingContinuation { continuation in
            let work: @MainActor () -> Void = {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "Choose an account"
                alert.informativeText = "Select which Google account should handle \(fileName)."
                alert.addButton(withTitle: "Continue")
                alert.addButton(withTitle: "Cancel")
                let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 26), pullsDown: false)
                popup.addItems(withTitles: accounts.map { $0.email })
                alert.accessoryView = popup
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    let index = popup.indexOfSelectedItem
                    let selected = accounts[index]
                    continuation.resume(returning: selected)
                } else {
                    continuation.resume(throwing: AccountSelector.SelectionError.userCancelled)
                }
            }
            Task { @MainActor in
                work()
            }
        }
    }
}
