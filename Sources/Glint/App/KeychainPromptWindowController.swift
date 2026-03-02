import AppKit
import SwiftUI

@MainActor
final class KeychainPromptWindowController: NSWindowController {
    private let image: NSImage?

    init(image: NSImage?) {
        self.image = image
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Keychain Access"
        super.init(window: window)
        window.contentView = NSHostingView(rootView: KeychainPromptView(image: image) { [weak self] in
            self?.dismiss(response: .OK)
        })
        window.center()
    }

    func presentModally() -> NSApplication.ModalResponse {
        guard let window else { return .abort }
        NSApp.activate(ignoringOtherApps: true)
        return NSApp.runModal(for: window)
    }

    private func dismiss(response: NSApplication.ModalResponse) {
        guard let window else { return }
        NSApp.stopModal(withCode: response)
        window.orderOut(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
