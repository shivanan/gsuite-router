import AppKit

final class DefaultHandlerPromptWindowController: NSWindowController {
    private let associationManager: DefaultAppAssociationManager
    private var checkboxMap: [DefaultAppAssociationManager.FileKind: NSButton] = [:]
    private let applyButton = NSButton(title: "Set as Default", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Not Now", target: nil, action: nil)
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
        super.init(window: panel)
        setupUI()
        refreshState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var hasUnsetDefaults: Bool {
        statuses.contains(where: { $0.value == false })
    }

    func refreshState() {
        statuses = associationManager.associationStatuses()
        for kind in DefaultAppAssociationManager.FileKind.allCases {
            let state = statuses[kind] ?? false
            checkboxMap[kind]?.state = state ? .off : .on
        }
        updateApplyButtonState()
    }

    override func close() {
        super.close()
        onDismiss?()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        let heading = NSTextField(labelWithString: "Select the file types that should open in GSuite Router by default.")
        heading.font = NSFont.systemFont(ofSize: 14)
        heading.lineBreakMode = .byWordWrapping

        container.addArrangedSubview(heading)

        let checkboxStack = NSStackView()
        checkboxStack.orientation = .vertical
        checkboxStack.spacing = 8

        for kind in DefaultAppAssociationManager.FileKind.allCases {
            let checkbox = NSButton(checkboxWithTitle: kind.displayLabel, target: self, action: #selector(checkboxToggled(_:)))
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            checkboxStack.addArrangedSubview(checkbox)
            checkboxMap[kind] = checkbox
        }
        container.addArrangedSubview(checkboxStack)

        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .trailing

        applyButton.target = self
        applyButton.action = #selector(applySelection)
        applyButton.keyEquivalent = "\r"
        cancelButton.target = self
        cancelButton.action = #selector(cancelSelection)

        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(applyButton)

        container.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            container.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    @objc private func checkboxToggled(_ sender: NSButton) {
        updateApplyButtonState()
    }

    @objc private func applySelection() {
        let selectedKinds = checkboxMap.compactMap { kind, button in
            button.state == .on ? kind : nil
        }
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

    @objc private func cancelSelection() {
        close()
    }

    private func updateApplyButtonState() {
        let anySelected = checkboxMap.values.contains { $0.state == .on }
        applyButton.isEnabled = anySelected
    }
}
