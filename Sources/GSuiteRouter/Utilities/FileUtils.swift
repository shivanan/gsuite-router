import Foundation
import UniformTypeIdentifiers

enum FileRouterError: Error, Equatable {
    case unsupportedType
    case authenticationMissing
    case uploadFailed
    case invalidResponse
    case userCancelled
}

struct SupportedFileKind {
    enum Kind {
        case excel
        case word
    }

    let kind: Kind
    let originalURL: URL

    static func classify(url: URL) -> SupportedFileKind? {
        let ext = url.pathExtension.lowercased()
        guard let uttype = UTType(filenameExtension: ext) else {
            return nil
        }
        if uttype.conforms(to: .spreadsheet) || ext == "xlsx" {
            return SupportedFileKind(kind: .excel, originalURL: url)
        }
        if uttype.conforms(to: UTType(filenameExtension: "docx") ?? .data) || ext == "docx" {
            return SupportedFileKind(kind: .word, originalURL: url)
        }
        return nil
    }

    static var acceptedTypes: [UTType] {
        var types: [UTType] = []
        if let xlsx = UTType(filenameExtension: "xlsx") {
            types.append(xlsx)
        }
        if let docx = UTType(filenameExtension: "docx") {
            types.append(docx)
        }
        return types
    }
}
