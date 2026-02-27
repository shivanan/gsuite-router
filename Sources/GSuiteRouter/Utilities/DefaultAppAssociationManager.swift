import Foundation
import UniformTypeIdentifiers
import CoreServices

struct DefaultAppAssociationManager {
    enum FileKind: CaseIterable {
        case word
        case excel

        var displayLabel: String {
            switch self {
            case .word: return "Word (.docx)"
            case .excel: return "Excel (.xlsx)"
            }
        }

        var utiIdentifier: String {
            switch self {
            case .word:
                return "org.openxmlformats.wordprocessingml.document"
            case .excel:
                return "org.openxmlformats.spreadsheetml.sheet"
            }
        }
    }

    private let bundleIdentifier: String

    init(bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "org.statictype.GSuiteRouter") {
        self.bundleIdentifier = bundleIdentifier
    }

    func currentHandler(for kind: FileKind) -> String? {
        guard let handler = LSCopyDefaultRoleHandlerForContentType(kind.utiIdentifier as CFString, LSRolesMask.all) else {
            return nil
        }
        return handler.takeRetainedValue() as String
    }

    func isDefault(for kind: FileKind) -> Bool {
        guard bundleIdentifier.isEmpty == false else { return false }
        return currentHandler(for: kind) == bundleIdentifier
    }

    func setAsDefault(for kinds: [FileKind]) throws {
        guard bundleIdentifier.isEmpty == false else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: [
                NSLocalizedDescriptionKey: "Missing bundle identifier; cannot register as default app."
            ])
        }
        for kind in kinds {
            try setAsDefault(for: kind)
        }
    }

    func associationStatuses() -> [FileKind: Bool] {
        var statuses: [FileKind: Bool] = [:]
        for kind in FileKind.allCases {
            statuses[kind] = isDefault(for: kind)
        }
        return statuses
    }

    func allKindsDefault() -> Bool {
        FileKind.allCases.allSatisfy { isDefault(for: $0) }
    }

    private func setAsDefault(for kind: FileKind) throws {
        let status = LSSetDefaultRoleHandlerForContentType(
            kind.utiIdentifier as CFString,
            LSRolesMask.all,
            bundleIdentifier as CFString
        )
        guard status == noErr else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to set default handler for \(kind.displayLabel)."
                ]
            )
        }
    }
}
