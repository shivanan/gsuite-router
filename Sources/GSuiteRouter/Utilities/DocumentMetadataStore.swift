import Foundation
import Darwin

struct DocumentMetadata: Codable {
    let documentURL: URL
    let accountID: String
    let accountEmail: String
    let uploadedAt: Date
    let uploaderVersion: String
}

struct DocumentMetadataStore {
    private static let attributeName = "com.shivanan.gsuite-router"

    static func save(_ metadata: DocumentMetadata, to fileURL: URL) throws {
        let data = try JSONEncoder().encode(metadata)
        try setExtendedAttribute(data, name: attributeName, url: fileURL)
    }

    static func load(from fileURL: URL) -> DocumentMetadata? {
        guard let data = try? getExtendedAttribute(name: attributeName, url: fileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(DocumentMetadata.self, from: data)
    }

    static func clear(from fileURL: URL) {
        _ = try? removeExtendedAttribute(name: attributeName, url: fileURL)
    }

    private static func setExtendedAttribute(_ data: Data, name: String, url: URL) throws {
        let path = url.path
        try data.withUnsafeBytes { bytes in
            let result = setxattr(path, name, bytes.baseAddress, data.count, 0, 0)
            if result != 0 {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }
    }

    private static func getExtendedAttribute(name: String, url: URL) throws -> Data {
        let path = url.path
        let size = getxattr(path, name, nil, 0, 0, 0)
        if size == -1 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { ptr in
            getxattr(path, name, ptr.baseAddress, size, 0, 0)
        }
        if result == -1 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return data
    }

    @discardableResult
    private static func removeExtendedAttribute(name: String, url: URL) throws -> Bool {
        let path = url.path
        let result = removexattr(path, name, 0)
        if result != 0 && errno != ENOATTR {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        return result == 0
    }
}
