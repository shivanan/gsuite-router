import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController {
    private let viewModel: PreferencesViewModel

    init(viewModel: PreferencesViewModel, setDefaultAction: @escaping () -> Void) {
        self.viewModel = viewModel
        let hostingView = NSHostingView(rootView: PreferencesView(viewModel: viewModel, onSetAsDefault: setDefaultAction))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Preferences"
        window.contentView = hostingView
        window.center()
        super.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
    }

    func refreshStatus() {
        viewModel.refreshStatus()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
