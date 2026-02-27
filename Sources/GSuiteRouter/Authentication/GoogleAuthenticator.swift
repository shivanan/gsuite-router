import Foundation
import Combine
import AppKit

@MainActor
final class GoogleAuthenticator: NSObject, ObservableObject {
    enum State: Equatable {
        case signedOut
        case signingIn
        case ready

        var requiresSignIn: Bool {
            if case .ready = self { return false }
            return true
        }
    }

    enum AuthError: Error, LocalizedError {
        case missingConfiguration
        case invalidRedirect
        case authorizationFailed
        case tokenExchangeFailed
        case notSignedIn

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET first."
            case .invalidRedirect:
                return "The OAuth redirect URL was invalid."
            case .authorizationFailed:
                return "Google authorization failed."
            case .tokenExchangeFailed:
                return "Could not exchange authorization code for tokens."
            case .notSignedIn:
                return "Please sign in first."
            }
        }
    }

    @Published private(set) var state: State = .signedOut
    @Published private(set) var accounts: [GoogleAccount] = [] {
        didSet {
            state = accounts.isEmpty ? .signedOut : .ready
        }
    }

    private let keychain = KeychainStore(service: "org.statictype.gsuite-router")
    private let accountsKey = "google-accounts"
    private let config = AppConfig.shared

    override init() {
        super.init()
        restore()
    }

    func restore() {
        guard let data = keychain.data(for: accountsKey) else { return }
        do {
            let stored = try JSONDecoder().decode([GoogleAccount].self, from: data)
            accounts = stored
        } catch {
            keychain.remove(accountsKey)
            accounts = []
        }
    }

    func signIn() async throws {
        guard config.isConfigured else { throw AuthError.missingConfiguration }
        state = .signingIn
        let server = LoopbackRedirectServer(path: config.loopbackPath)
        let redirectURL = try await server.start()
        defer { server.stop() }
        let stateToken = UUID().uuidString
        let authURL = buildAuthenticationURL(redirectURI: redirectURL.absoluteString, state: stateToken)
        do {
            _ = await MainActor.run {
                NSWorkspace.shared.open(authURL)
            }
            let callbackURL = try await withTaskCancellationHandler(operation: {
                try await server.waitForCallback()
            }, onCancel: {
                server.cancelWaiting()
            })
            let tokens = try await exchangeCode(from: callbackURL, redirectURI: redirectURL.absoluteString, expectedState: stateToken)
            let userInfo = try await fetchUserInfo(accessToken: tokens.accessToken)
            upsertAccount(id: userInfo.sub, email: userInfo.email, tokens: tokens)
            self.state = .ready
        } catch {
            self.state = .signedOut
            if case LoopbackRedirectServer.ServerError.cancelled = error {
                throw AuthError.authorizationFailed
            }
            throw error
        }
    }

    func signOut(accountID: String) {
        accounts.removeAll { $0.id == accountID }
        persistAccounts()
    }

    func validAccessToken(for accountID: String) async throws -> String {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            throw AuthError.notSignedIn
        }
        var account = accounts[index]
        if account.tokens.isExpired {
            let refreshed = try await refreshToken(using: account.tokens)
            account.tokens = refreshed
            accounts[index] = account
            persistAccounts()
            return refreshed.accessToken
        }
        return account.tokens.accessToken
    }

    private func buildAuthenticationURL(redirectURI: String, state: String) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/userinfo.email"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "state", value: state)
        ]
        return components.url!
    }

    private func exchangeCode(from callbackURL: URL, redirectURI: String, expectedState: String) async throws -> AuthTokens {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidRedirect
        }
        let queryItems = components.queryItems ?? []
        if let stateValue = queryItems.first(where: { $0.name == "state" })?.value, stateValue != expectedState {
            throw AuthError.invalidRedirect
        }
        if queryItems.contains(where: { $0.name == "error" }) {
            throw AuthError.authorizationFailed
        }
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw AuthError.invalidRedirect
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        let bodyItems: [URLQueryItem] = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "client_secret", value: config.clientSecret),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code")
        ]
        request.httpBody = bodyItems.percentEncoded()
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.tokenExchangeFailed
        }
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let refreshToken = tokenResponse.refreshToken else {
            throw AuthError.tokenExchangeFailed
        }
        let expiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        let tokens = AuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: refreshToken,
            expirationDate: expiry
        )
        return tokens
    }

    private func refreshToken(using tokens: AuthTokens) async throws -> AuthTokens {
        guard tokens.refreshToken.isEmpty == false else {
            throw AuthError.tokenExchangeFailed
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        let items: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "client_secret", value: config.clientSecret),
            URLQueryItem(name: "refresh_token", value: tokens.refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        request.httpBody = items.percentEncoded()
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.tokenExchangeFailed
        }
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        return AuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokens.refreshToken,
            expirationDate: expiry
        )
    }

    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.authorizationFailed
        }
        return try JSONDecoder().decode(UserInfo.self, from: data)
    }

    private func upsertAccount(id: String, email: String, tokens: AuthTokens) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].email = email
            accounts[index].tokens = tokens
        } else {
            let account = GoogleAccount(id: id, email: email, tokens: tokens)
            accounts.append(account)
        }
        persistAccounts()
    }

    private func persistAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            try? keychain.set(data, for: accountsKey)
        } else {
            keychain.remove(accountsKey)
        }
    }
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expirationDate: Date

    var isExpired: Bool {
        expirationDate.timeIntervalSinceNow < 60
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

struct GoogleAccount: Identifiable, Codable {
    let id: String
    var email: String
    var tokens: AuthTokens
}

private struct UserInfo: Decodable {
    let email: String
    let sub: String
}

private extension Array where Element == URLQueryItem {
    func percentEncoded() -> Data {
        var components = URLComponents()
        components.queryItems = self
        return components.percentEncodedQuery?.data(using: .utf8) ?? Data()
    }
}
