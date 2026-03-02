import AppKit

@MainActor
final class KeychainPromptCoordinator {
    static let shared = KeychainPromptCoordinator()
    private let defaults = UserDefaults.standard

    private init() {}

    func presentIfNeeded() {
        guard defaults.bool(forKey: UserPreferenceKeys.hasAcknowledgedKeychainPrompt) == false else { return; }
        let controller = KeychainPromptWindowController(image: promptImage())
        let response = controller.presentModally()
        if response == .OK {
            defaults.set(true, forKey: UserPreferenceKeys.hasAcknowledgedKeychainPrompt)
        }
    }

    private func promptImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "KeychainPrompt", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: "KeychainPrompt", withExtension: "jpg") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
