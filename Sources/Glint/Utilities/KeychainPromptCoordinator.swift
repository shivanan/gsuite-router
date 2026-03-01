import AppKit

@MainActor
final class KeychainPromptCoordinator {
    static let shared = KeychainPromptCoordinator()
    private let defaults = UserDefaults.standard

    private init() {}

    func presentIfNeeded() {
        guard defaults.bool(forKey: UserPreferenceKeys.hasAcknowledgedKeychainPrompt) == false else { return }
        let alert = NSAlert()
        alert.messageText = "Allow Glint to access your Keychain"
        alert.informativeText = """
Glint stores Google account tokens securely in the macOS Keychain. macOS will now show a system dialog asking whether Glint can read those tokens. Please choose “Always Allow” so you won’t see the prompt again.
"""
        alert.addButton(withTitle: "Continue")
        alert.runModal()
        defaults.set(true, forKey: UserPreferenceKeys.hasAcknowledgedKeychainPrompt)
    }
}
