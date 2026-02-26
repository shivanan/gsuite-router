import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            accountsPanel
            statusPanel
            actionBar
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 360)
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
