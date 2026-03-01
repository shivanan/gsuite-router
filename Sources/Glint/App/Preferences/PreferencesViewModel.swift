import Foundation

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var isWordDefault: Bool = false
    @Published var isExcelDefault: Bool = false

    private let associationManager: DefaultAppAssociationManager

    init(associationManager: DefaultAppAssociationManager) {
        self.associationManager = associationManager
        refreshStatus()
    }

    func refreshStatus() {
        isWordDefault = associationManager.isDefault(for: .word)
        isExcelDefault = associationManager.isDefault(for: .excel)
    }

    var allKindsAreDefault: Bool {
        isWordDefault && isExcelDefault
    }
}
