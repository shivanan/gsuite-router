import Foundation

struct AppConfig {
    static let shared = AppConfig()

    let clientID: String
    let clientSecret: String
    let loopbackPath: String = "oauth2redirect"
    let driveFolderID: String?

    private init() {
        if let secrets = Self.loadSecrets() {
            clientID = secrets.clientID ?? ""
            clientSecret = secrets.clientSecret ?? ""
            driveFolderID = secrets.driveFolderID
        } else {
            let env = ProcessInfo.processInfo.environment
            clientID = env["GOOGLE_CLIENT_ID"] ?? ""
            clientSecret = env["GOOGLE_CLIENT_SECRET"] ?? ""
            driveFolderID = env["GOOGLE_DRIVE_FOLDER_ID"]
        }
    }

    var isConfigured: Bool {
        !clientID.isEmpty && !clientSecret.isEmpty
    }

    private static func loadSecrets() -> Secrets? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? PropertyListDecoder().decode(Secrets.self, from: data)
    }
}

private struct Secrets: Decodable {
    let clientID: String?
    let clientSecret: String?
    let driveFolderID: String?

    enum CodingKeys: String, CodingKey {
        case clientID = "GoogleClientID"
        case clientSecret = "GoogleClientSecret"
        case driveFolderID = "GoogleDriveFolderID"
    }
}
