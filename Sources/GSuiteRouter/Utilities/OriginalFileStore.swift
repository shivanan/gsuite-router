import Foundation
import CryptoKit

struct StoredOriginalInfo {
    let hash: String
    let storedURL: URL
    let fileSize: Int
}

struct OriginalFileStore: @unchecked Sendable {
    static let shared = OriginalFileStore()

    private let directory: URL
    private let fileManager = FileManager.default

    private init() {
        let home = fileManager.homeDirectoryForCurrentUser
        directory = home.appendingPathComponent(".gsuiterouter/originals", isDirectory: true)
    }

    func persist(fileURL: URL) throws -> StoredOriginalInfo {
        let data = try Data(contentsOf: fileURL)
        let hash = Self.sha256Hex(for: data)
        let targetURL = directory.appendingPathComponent(hash, isDirectory: false)
        try ensureDirectory()
        if fileManager.fileExists(atPath: targetURL.path) == false {
            try data.write(to: targetURL, options: [.atomic])
        }
        return StoredOriginalInfo(hash: hash, storedURL: targetURL, fileSize: data.count)
    }

    func url(for hash: String) -> URL {
        directory.appendingPathComponent(hash, isDirectory: false)
    }

    private func ensureDirectory() throws {
        if fileManager.fileExists(atPath: directory.path) == false {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static func sha256Hex(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
