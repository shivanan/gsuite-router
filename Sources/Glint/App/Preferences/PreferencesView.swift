import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    var onSetAsDefault: () -> Void
    @AppStorage(UserPreferenceKeys.autoSetDefaultHandlerPerFile) private var autoSetDefaultPerFile: Bool = false
    @AppStorage(UserPreferenceKeys.applyCustomIconPerFile) private var applyCustomIconPerFile: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Default App Settings")
                .font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 12) {
                defaultStatusRow(label: "Word (.docx)", isDefault: viewModel.isWordDefault)
                defaultStatusRow(label: "Excel (.xlsx)", isDefault: viewModel.isExcelDefault)
            }
            Text("Use the button below to pick which file types should open with Glint.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Set as the default app for Excel and Word files") {
                onSetAsDefault()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.allKindsAreDefault)
            if viewModel.allKindsAreDefault {
                Text("Glint already handles Word and Excel files.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Set routed files to open in Glint automatically", isOn: $autoSetDefaultPerFile)
                Toggle("Apply the Glint icon to routed files", isOn: $applyCustomIconPerFile)
            }
            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 280)
        .onAppear {
            viewModel.refreshStatus()
        }
    }

    private func defaultStatusRow(label: String, isDefault: Bool) -> some View {
        HStack {
            Image(systemName: isDefault ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isDefault ? .green : .secondary)
            Text(isDefault ? "\(label): Glint" : "\(label): Other app")
        }
    }
}
