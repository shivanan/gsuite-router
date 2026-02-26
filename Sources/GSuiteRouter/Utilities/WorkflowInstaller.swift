import Foundation

struct WorkflowInstaller {
    enum InstallerError: Error, LocalizedError {
        case bundleMissing
        case copyFailed(String)

        var errorDescription: String? {
            switch self {
            case .bundleMissing:
                return "RestoreOriginal.workflow bundle is missing from the app."
            case .copyFailed(let reason):
                return "Could not install shortcut: \(reason)"
            }
        }
    }

    static func installRestoreWorkflow() throws -> URL {
        guard let archiveURL = resourceURL(named: "RestoreOriginal.workflow", extension: "zip") else {
            throw InstallerError.bundleMissing
        }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Self.unzip(archiveURL: archiveURL, destination: tempDir)
        let bundleURL = tempDir.appendingPathComponent("RestoreOriginal.workflow")
        let servicesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services", isDirectory: true)
        let destination = servicesDir.appendingPathComponent("RestoreOriginal.workflow")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: servicesDir.path, isDirectory: &isDir) == false {
            try FileManager.default.createDirectory(at: servicesDir, withIntermediateDirectories: true)
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        do {
            try FileManager.default.copyItem(at: bundleURL, to: destination)
        } catch {
            throw InstallerError.copyFailed(error.localizedDescription)
        }
        return destination
    }

    private static func unzip(archiveURL: URL, destination: URL) throws {
        let process = Process()
        process.launchPath = "/usr/bin/ditto"
        process.arguments = ["-x", "-k", archiveURL.path, destination.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw InstallerError.copyFailed("ditto failed with code \(process.terminationStatus)")
        }
    }

    private static func resourceURL(named name: String, extension ext: String) -> URL? {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        #endif
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
}
