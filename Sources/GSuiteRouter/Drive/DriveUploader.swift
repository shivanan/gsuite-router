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

    func uploadAndConvert(fileURL: URL, target: ConversionTarget, accountID: String) async throws -> UploadResult {
        let accessToken = try await authenticator.validAccessToken(for: accountID)
        let metadata = makeMetadata(for: fileURL, target: target)
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

    private func makeMetadata(for url: URL, target: ConversionTarget) -> [String: Any] {
        var metadata: [String: Any] = [
            "name": url.deletingPathExtension().lastPathComponent,
            "mimeType": target.googleMimeType
        ]
        if let folder = config.driveFolderID, folder.isEmpty == false {
            metadata["parents"] = [folder]
        }
        return metadata
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
