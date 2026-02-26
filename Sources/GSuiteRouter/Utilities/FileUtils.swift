import Foundation
import UniformTypeIdentifiers

enum FileRouterError: Error {
    case unsupportedType
    case authenticationMissing
    case uploadFailed
    case invalidResponse
    case invalidLinkFile
}

struct SupportedFileKind {
    enum Kind {
        case excel
        case word
        case shortcut
    }

    let kind: Kind
    let originalURL: URL

    static func classify(url: URL) -> SupportedFileKind? {
        let ext = url.pathExtension.lowercased()
        if ext == "gdoc" {
            return SupportedFileKind(kind: .shortcut, originalURL: url)
        }
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
        var types: [UTType] = [.data]
        if let xlsx = UTType(filenameExtension: "xlsx") {
            types.append(xlsx)
        }
        if let docx = UTType(filenameExtension: "docx") {
            types.append(docx)
        }
        return types
    }
}

struct FileReplacementResult {
    let trashedURL: URL
    let shortcutURL: URL
}

enum ShortcutLinkError: Error {
    case encodingFailed
    case decodingFailed
}

struct GDocLinkFile: Codable {
    let documentURL: URL
    let originalFilename: String
    let uploadedAt: Date
    let uploaderVersion: String
}

struct FileUtilities {
    static func trashOriginalAndCreateShortcut(originalURL: URL, link: GDocLinkFile) throws -> FileReplacementResult {
        let fileManager = FileManager.default
        var resultingURL: NSURL?
        try fileManager.trashItem(at: originalURL, resultingItemURL: &resultingURL)

        let shortcutURL = originalURL.appendingPathExtension("gdoc")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(link)
        if fileManager.fileExists(atPath: shortcutURL.path) {
            try fileManager.removeItem(at: shortcutURL)
        }
        fileManager.createFile(atPath: shortcutURL.path, contents: data)
        return FileReplacementResult(
            trashedURL: resultingURL?.absoluteURL ?? originalURL,
            shortcutURL: shortcutURL
        )
    }

    static func loadShortcut(from url: URL) throws -> GDocLinkFile {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(GDocLinkFile.self, from: data)
    }
}
