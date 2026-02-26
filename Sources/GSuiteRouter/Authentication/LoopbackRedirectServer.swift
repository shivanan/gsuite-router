import Foundation
import Network

final class LoopbackRedirectServer: @unchecked Sendable {
    enum ServerError: Error {
        case failedToStart
        case cancelled
    }

    private let callbackPath: String
    private var listener: NWListener?
    private var callbackContinuation: CheckedContinuation<URL, Error>?
    private let queue = DispatchQueue(label: "LoopbackRedirectServer")

    init(path: String) {
        if path.hasPrefix("/") {
            self.callbackPath = path
        } else {
            self.callbackPath = "/" + path
        }
    }

    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let listener = try NWListener(using: .tcp, on: .any)
                listener.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        guard let port = listener.port else {
                            continuation.resume(throwing: ServerError.failedToStart)
                            self.stop()
                            return
                        }
                        var components = URLComponents()
                        components.scheme = "http"
                        components.host = "127.0.0.1"
                        components.port = Int(port.rawValue)
                        components.path = self.callbackPath
                        guard let redirectURL = components.url else {
                            continuation.resume(throwing: ServerError.failedToStart)
                            self.stop()
                            return
                        }
                        continuation.resume(returning: redirectURL)
                    case .failed(let error):
                        continuation.resume(throwing: error)
                        self.stop()
                    default:
                        break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in
                    self?.handle(connection: connection)
                }
                listener.start(queue: queue)
                self.listener = listener
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func waitForCallback() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.callbackContinuation = continuation
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func cancelWaiting() {
        callbackContinuation?.resume(throwing: ServerError.cancelled)
        callbackContinuation = nil
        stop()
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, error in
            guard let self else { return }
            guard error == nil, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            guard let requestLine = request.components(separatedBy: "\r\n").first else {
                self.respondInvalid(connection: connection)
                return
            }
            let parts = requestLine.split(separator: " ")
            guard parts.count >= 2 else {
                self.respondInvalid(connection: connection)
                return
            }
            let path = String(parts[1])
            guard path.hasPrefix(self.callbackPath) else {
                self.respondNotFound(connection: connection)
                return
            }
            let callbackURLString = "http://127.0.0.1\(path)"
            guard let url = URL(string: callbackURLString) else {
                self.respondInvalid(connection: connection)
                return
            }
            self.respondSuccess(connection: connection)
            self.callbackContinuation?.resume(returning: url)
            self.callbackContinuation = nil
            self.stop()
        }
    }

    private func respondSuccess(connection: NWConnection) {
        let body = "<html><body>You may return to GSuite Router.</body></html>"
        send(connection: connection, status: "200 OK", body: body)
    }

    private func respondInvalid(connection: NWConnection) {
        send(connection: connection, status: "400 Bad Request", body: "Invalid request")
    }

    private func respondNotFound(connection: NWConnection) {
        send(connection: connection, status: "404 Not Found", body: "Not Found")
    }

    private func send(connection: NWConnection, status: String, body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
