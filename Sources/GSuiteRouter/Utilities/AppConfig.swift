import Foundation

struct AppConfig {
    static let shared = AppConfig()

    let clientID: String
    let clientSecret: String
    let loopbackPath: String = "oauth2redirect"
    let driveFolderID: String?

    private init() {
        let env = ProcessInfo.processInfo.environment
        clientID = env["GOOGLE_CLIENT_ID"] ?? ""
        clientSecret = env["GOOGLE_CLIENT_SECRET"] ?? ""
        driveFolderID = env["GOOGLE_DRIVE_FOLDER_ID"]
    }

    var isConfigured: Bool {
        !clientID.isEmpty && !clientSecret.isEmpty
    }
}
