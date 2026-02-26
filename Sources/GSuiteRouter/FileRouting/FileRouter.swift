import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

final class FileRouter {
    enum Event {
        case started(String)
        case finished(String)
        case failed(Error)
    }

    let eventPublisher = PassthroughSubject<Event, Never>()

    private let driveUploader: DriveUploader
    private let authenticator: GoogleAuthenticator
    private let originalStore = OriginalFileStore.shared
    private let workspace = NSWorkspace.shared

    init(driveUploader: DriveUploader, authenticator: GoogleAuthenticator) {
        self.driveUploader = driveUploader
        self.authenticator = authenticator
    }

    func handleFileOpen(url: URL) -> Bool {
        guard let classification = SupportedFileKind.classify(url: url) else {
            return false
        }
        Task { [weak self] in
            guard let self else { return }
            await self.process(classification)
        }
        return true
    }

    private func process(_ classification: SupportedFileKind) async {
        switch classification.kind {
        case .shortcut:
            await openShortcut(at: classification.originalURL)
        case .excel:
            await uploadAndReplace(url: classification.originalURL, targetType: .spreadsheet)
        case .word:
            await uploadAndReplace(url: classification.originalURL, targetType: .document)
        }
    }

    private func openShortcut(at url: URL) async {
        eventPublisher.send(.started("Opening Google Doc link"))
        do {
            let link = try FileUtilities.loadShortcut(from: url)
            _ = await MainActor.run {
                workspace.open(link.documentURL)
            }
            eventPublisher.send(.finished("Opened \(link.documentURL.absoluteString)"))
        } catch {
            eventPublisher.send(.failed(error))
        }
    }

    private func uploadAndReplace(url: URL, targetType: DriveUploader.ConversionTarget) async {
        eventPublisher.send(.started("Uploading \(url.lastPathComponent)"))
        do {
            let state = await MainActor.run { authenticator.state }
            guard state == .ready else {
                throw FileRouterError.authenticationMissing
            }
            let uploadResult = try await driveUploader.uploadAndConvert(fileURL: url, target: targetType)
            let storedOriginal = try originalStore.persist(fileURL: url)
            let fileUTType = UTType(filenameExtension: url.pathExtension.lowercased())?.identifier
            let link = GDocLinkFile(
                documentURL: uploadResult.webViewLink,
                originalFilename: url.lastPathComponent,
                uploadedAt: Date(),
                uploaderVersion: "0.1.0",
                originalBlobHash: storedOriginal.hash,
                originalTypeIdentifier: fileUTType,
                originalFileSize: storedOriginal.fileSize
            )
            _ = try FileUtilities.trashOriginalAndCreateShortcut(originalURL: url, link: link)
            eventPublisher.send(.finished("Rerouted to Google Docs"))
        } catch {
            eventPublisher.send(.failed(error))
        }
    }
}

extension FileRouter: @unchecked Sendable {}
