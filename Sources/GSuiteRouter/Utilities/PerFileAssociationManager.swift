import Foundation
import Darwin

enum PerFileAssociationManager {
    private static let attributeName = "com.apple.LaunchServices.OpenWith"

    static func applyDefaultHandler(to url: URL) throws {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let bundlePath = Bundle.main.bundlePath
        let payload: [String: Any] = [
            "bundleidentifier": bundleIdentifier,
            "path": bundlePath,
            "version": 0
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)
        try setExtendedAttribute(data, name: attributeName, url: url)
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
}
