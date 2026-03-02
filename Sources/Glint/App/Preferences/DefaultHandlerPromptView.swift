import SwiftUI

@MainActor
final class DefaultHandlerPromptState: ObservableObject {
    @Published private(set) var selections: [DefaultAppAssociationManager.FileKind: Bool] = [:]

    func update(with statuses: [DefaultAppAssociationManager.FileKind: Bool]) {
        var next: [DefaultAppAssociationManager.FileKind: Bool] = [:]
        for (kind, isDefault) in statuses {
            next[kind] = !isDefault
        }
        selections = next
    }

    func binding(for kind: DefaultAppAssociationManager.FileKind) -> Binding<Bool> {
        Binding(
            get: { self.selections[kind] ?? false },
            set: { self.selections[kind] = $0 }
        )
    }

    var selectedKinds: [DefaultAppAssociationManager.FileKind] {
        selections.compactMap { $0.value ? $0.key : nil }
    }

    var applyEnabled: Bool {
        selections.values.contains(true)
    }
}

struct DefaultHandlerPromptView: View {
    @ObservedObject var state: DefaultHandlerPromptState
    var applyAction: () -> Void
    var cancelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose file types for Glint")
                .font(.system(size: 20, weight: .semibold))
            Text("Select the document types Glint should open by default. Finder will route those files to Glint automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(DefaultAppAssociationManager.FileKind.allCases), id: \.self) { kind in
                    Toggle(kind.displayLabel, isOn: state.binding(for: kind))
                }
            }
            HStack {
                Button("Not Now", action: cancelAction)
                    .buttonStyle(.borderless)
                Spacer()
                Button("Set as Default", action: applyAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.applyEnabled)
            }
        }
        .padding(24)
        .frame(width: 420, height: 240)
    }
}
