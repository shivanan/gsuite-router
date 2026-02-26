import AppKit
import SwiftUI

final class MainWindowController: NSWindowController {
    init(viewModel: MainViewModel) {
        let hostingView = NSHostingView(rootView: MainView(viewModel: viewModel))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .miniaturizable, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "GSuite Router"
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
