import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    var onSetAsDefault: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Default App Settings")
                .font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 12) {
                defaultStatusRow(label: "Word (.docx)", isDefault: viewModel.isWordDefault)
                defaultStatusRow(label: "Excel (.xlsx)", isDefault: viewModel.isExcelDefault)
            }
            Text("Use the button below to pick which file types should open with GSuite Router.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Set as the default app for Excel and Word files") {
                onSetAsDefault()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.allKindsAreDefault)
            if viewModel.allKindsAreDefault {
                Text("GSuite Router already handles Word and Excel files.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 240)
        .onAppear {
            viewModel.refreshStatus()
        }
    }

    private func defaultStatusRow(label: String, isDefault: Bool) -> some View {
        HStack {
            Image(systemName: isDefault ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isDefault ? .green : .secondary)
            Text(isDefault ? "\(label): GSuite Router" : "\(label): Other app")
        }
    }
}
