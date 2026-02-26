import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
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

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
            }
            if let email = viewModel.userEmail {
                Text("Signed in as \(email)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            switch viewModel.operationState {
            case .idle:
                Text("Drop .docx or .xlsx files onto the app, or set GSuite Router as the default handler.")
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
            if viewModel.authState.requiresSignIn {
                Button("Sign in with Google") {
                    viewModel.signIn()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Sign out") {
                    viewModel.signOut()
                }
            }

            Button("Choose Files…") {
                viewModel.manualFileSelection()
            }
            .disabled(viewModel.authState.requiresSignIn)
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

