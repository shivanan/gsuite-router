import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct MainView: View {
    @ObservedObject var viewModel: MainViewModel

    @State private var dropActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            accountsPanel
            statusPanel
            actionBar
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 360)
        .onDrop(of: [UTType.fileURL], isTargeted: $dropActive) { providers in
            handleDrop(providers: providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dropActive ? Color.accentColor : Color.clear, lineWidth: 3)
                .animation(.easeInOut(duration: 0.2), value: dropActive)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GSuite Router")
                .font(.system(size: 28, weight: .bold))
            Text("Route Office files to Google Docs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var accountsPanel: some View {
        GroupBox(label: Text("Accounts")) {
            if viewModel.accounts.isEmpty {
                Text("No Google accounts connected. Click ‘Add Account’ to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.accounts) { account in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(account.email)
                                    .font(.body)
                                Text("ID: \(account.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Sign Out") {
                                viewModel.signOut(accountID: account.id)
                            }
                        }
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private var statusPanel: some View {
        GroupBox(label: Text("Status")) {
            VStack(alignment: .leading, spacing: 12) {
                if let account = viewModel.activeAccountEmail {
                    Text("Active: \(account)")
                        .font(.subheadline)
                }
                switch viewModel.operationState {
                case .idle:
                    Text(viewModel.accounts.isEmpty ? "Add an account to begin." : "Drop .docx/.xlsx files on this icon or use Choose Files…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                case .working(let message):
                    ProgressView(message)
                        .progressViewStyle(.linear)
                case .completed(let message):
                    Label(message, systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                case .failed(let reason):
                    Label(reason, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionBar: some View {
        HStack {
            Button("Add Account") {
                viewModel.signIn()
            }
            Button("Choose Files…") {
                viewModel.manualFileSelection()
            }
            .disabled(viewModel.accounts.isEmpty)
            Spacer()
        }
    }
}

private extension MainView {
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = Self.resolveURL(from: item) else { return }
                Task { @MainActor in
                    viewModel.openFiles(at: [url])
                }
            }
        }
        return handled
    }

    nonisolated static func resolveURL(from item: NSSecureCoding?) -> URL? {
        if let data = item as? Data,
           let path = String(data: data, encoding: .utf8) {
            return URL(string: path)
        }
        if let url = item as? URL {
            return url
        }
        return nil
    }
}
