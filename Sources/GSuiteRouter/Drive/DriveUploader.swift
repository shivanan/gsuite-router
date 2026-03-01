import Foundation
import UniformTypeIdentifiers

struct UploadResult {
    let id: String
    let webViewLink: URL
}

final class DriveUploader {
    enum ConversionTarget {
        case spreadsheet
        case document

        var googleMimeType: String {
            switch self {
            case .spreadsheet:
                return "application/vnd.google-apps.spreadsheet"
            case .document:
                return "application/vnd.google-apps.document"
            }
        }

        var uploadContentType: String {
            switch self {
            case .spreadsheet:
                return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            case .document:
                return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            }
        }
    }

    private let authenticator: GoogleAuthenticator
    private let session: URLSession
    private let config = AppConfig.shared

    init(authenticator: GoogleAuthenticator, session: URLSession = .shared) {
        self.authenticator = authenticator
        self.session = session
    }

    func uploadAndConvert(fileURL: URL, target: ConversionTarget, account: GoogleAccount) async throws -> UploadResult {
        let accessToken = try await authenticator.validAccessToken(for: account.id)
        let parentFolderID = try await preferredFolderID(for: account, accessToken: accessToken)
        let metadata = makeMetadata(for: fileURL, target: target, parentFolderID: parentFolderID)
        let fileData = try Data(contentsOf: fileURL)
        let body = try buildMultipartBody(metadata: metadata, fileData: fileData, fileMimeType: target.uploadContentType)

        var components = URLComponents(string: "https://www.googleapis.com/upload/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "fields", value: "id,webViewLink")
        ]
        guard let url = components.url else {
            throw FileRouterError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = body.boundary
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown"
            throw NSError(domain: "DriveUploader", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Drive upload failed: \(errorMessage)"])
        }
        let result = try JSONDecoder().decode(DriveUploadResponse.self, from: data)
        guard let linkString = result.webViewLink, let linkURL = URL(string: linkString) else {
            throw FileRouterError.invalidResponse
        }
        return UploadResult(id: result.id, webViewLink: linkURL)
    }

    private func makeMetadata(for url: URL, target: ConversionTarget, parentFolderID: String?) -> [String: Any] {
        var metadata: [String: Any] = [
            "name": url.deletingPathExtension().lastPathComponent,
            "mimeType": target.googleMimeType
        ]
        if let folder = parentFolderID ?? config.driveFolderID, folder.isEmpty == false {
            metadata["parents"] = [folder]
        }
        return metadata
    }

    private func preferredFolderID(for account: GoogleAccount, accessToken: String) async throws -> String? {
        guard let desiredName = account.preferredFolderName, desiredName.isEmpty == false else {
            return nil
        }
        if let cached = account.preferredFolderID {
            return cached
        }
        let folderID: String
        if let existing = try await findFolder(named: desiredName, accessToken: accessToken) {
            folderID = existing
        } else {
            folderID = try await createFolder(named: desiredName, accessToken: accessToken)
        }
        await authenticator.cachePreferredFolderID(folderID, for: account.id)
        return folderID
    }

    private func findFolder(named name: String, accessToken: String) async throws -> String? {
        let escapedName = name.replacingOccurrences(of: "'", with: "\\'")
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "name = '\(escapedName)' and mimeType = 'application/vnd.google-apps.folder' and trashed = false and 'root' in parents"),
            URLQueryItem(name: "spaces", value: "drive"),
            URLQueryItem(name: "fields", value: "files(id)"),
            URLQueryItem(name: "pageSize", value: "1"),
            URLQueryItem(name: "supportsAllDrives", value: "true")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown"
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "DriveUploader", code: status, userInfo: [NSLocalizedDescriptionKey: "Folder lookup failed: \(message)"])
        }
        let decoded = try JSONDecoder().decode(FolderListResponse.self, from: data)
        return decoded.files.first?.id
    }

    private func createFolder(named name: String, accessToken: String) async throws -> String {
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "fields", value: "id")
        ]
        guard let url = components.url else {
            throw FileRouterError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder",
            "parents": ["root"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown"
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "DriveUploader", code: status, userInfo: [NSLocalizedDescriptionKey: "Folder creation failed: \(message)"])
        }
        let decoded = try JSONDecoder().decode(FolderCreateResponse.self, from: data)
        return decoded.id
    }

    private func buildMultipartBody(metadata: [String: Any], fileData: Data, fileMimeType: String) throws -> (data: Data, boundary: String) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Type: application/json; charset=UTF-8\r\n\r\n")
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        body.append(metadataData)
        body.appendString("\r\n")

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Type: \(fileMimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        return (data: body, boundary: boundary)
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

private struct DriveUploadResponse: Decodable {
    let id: String
    let webViewLink: String?
}

private struct FolderListResponse: Decodable {
    struct Entry: Decodable { let id: String }
    let files: [Entry]
}

private struct FolderCreateResponse: Decodable {
    let id: String
}
