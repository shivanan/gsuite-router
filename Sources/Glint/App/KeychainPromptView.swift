import SwiftUI

struct KeychainPromptView: View {
    let image: NSImage?
    let continueAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow Glint to access your Keychain")
                    .font(.system(size: 20, weight: .semibold))
                Text("Glint stores your Google account tokens securely in the macOS Keychain. macOS will now show a system dialog asking for access. Choose “Always Allow” to skip this prompt in the future.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 420, alignment: .leading)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quinary)
                    .frame(height: 180)
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                } else {
                    Text("Screenshot goes here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Continue") {
                continueAction()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
