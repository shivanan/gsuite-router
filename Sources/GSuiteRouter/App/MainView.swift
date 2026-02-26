import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            accountsSection
            Divider()
            status
            Divider()
            actions
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 260)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GSuite Router")
                .font(.system(size: 26, weight: .bold))
            Text("Automatically move Office documents into Google Docs")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connected accounts")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(viewModel.accounts.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            if viewModel.accounts.isEmpty {
                Text("No Google accounts connected. Add at least one to start routing files.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.accounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.email)
                                .font(.system(size: 13, weight: .medium))
                            Text("ID: \(account.id)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Sign out") {
                            viewModel.signOut(accountID: account.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
            }
            switch viewModel.operationState {
            case .idle:
                Text(viewModel.accounts.isEmpty ? "Add a Google account to begin routing files." : "Drop .docx or .xlsx files onto the app, or set GSuite Router as the default handler.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            case .working(let message):
                ProgressView(message)
                    .progressViewStyle(.linear)
            case .completed(let message):
                Label(message, systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                    .font(.system(size: 12))
            case .failed(let reason):
                Label(reason, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.system(size: 12))
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Add Google Account") {
                viewModel.signIn()
            }
            .buttonStyle(.borderedProminent)
            Button("Choose Files…") {
                viewModel.manualFileSelection()
            }
            .disabled(viewModel.accounts.isEmpty)
            Spacer()
        }
    }

    private var statusColor: Color {
        switch viewModel.authState {
        case .signedOut:
            return .red
        case .signingIn:
            return .orange
        case .ready:
            return .green
        }
    }

    private var statusText: String {
        switch viewModel.authState {
        case .signedOut:
            return "Not connected"
        case .signingIn:
            return "Connecting…"
        case .ready:
            return "Connected"
        }
    }
}
