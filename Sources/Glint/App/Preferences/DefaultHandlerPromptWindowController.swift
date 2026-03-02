import AppKit
import SwiftUI

@MainActor
final class DefaultHandlerPromptWindowController: NSWindowController {
    private let associationManager: DefaultAppAssociationManager
    private let state = DefaultHandlerPromptState()
    private var statuses: [DefaultAppAssociationManager.FileKind: Bool] = [:]

    var onCompletion: (() -> Void)?
    var onDismiss: (() -> Void)?

    init(associationManager: DefaultAppAssociationManager) {
        self.associationManager = associationManager
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Choose Default File Types"
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.center()
        super.init(window: panel)
        let content = DefaultHandlerPromptView(
            state: state,
            applyAction: { [weak self] in self?.applySelection() },
            cancelAction: { [weak self] in self?.cancelSelection() }
        )
        panel.contentView = NSHostingView(rootView: content)
        refreshState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshState() {
        statuses = associationManager.associationStatuses()
        state.update(with: statuses)
    }

    override func close() {
        window?.orderOut(nil)
        super.close()
        onDismiss?()
    }

    private func applySelection() {
        let selectedKinds = state.selectedKinds
        guard selectedKinds.isEmpty == false else { return }
        do {
            try associationManager.setAsDefault(for: selectedKinds)
            refreshState()
            onCompletion?()
            close()
        } catch {
            let alert = NSAlert(error: error)
            alert.beginSheetModal(for: window ?? NSWindow(), completionHandler: nil)
        }
    }

    private func cancelSelection() {
        close()
    }
}
