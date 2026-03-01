import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

final class FileRouter {
    enum Event {
        case started(String, GoogleAccount?)
        case finished(String)
        case failed(Error)
    }

    let eventPublisher = PassthroughSubject<Event, Never>()

    private let driveUploader: DriveUploader
    private let accountSelector: AccountSelector
    private let workspace = NSWorkspace.shared

    init(driveUploader: DriveUploader, accountSelector: AccountSelector) {
        self.driveUploader = driveUploader
        self.accountSelector = accountSelector
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
        if let metadata = DocumentMetadataStore.load(from: classification.originalURL) {
            await openRemoteDocument(using: metadata)
            return
        }
        switch classification.kind {
        case .excel:
            await uploadAndAnnotate(url: classification.originalURL, targetType: .spreadsheet)
        case .word:
            await uploadAndAnnotate(url: classification.originalURL, targetType: .document)
        }
    }

    private func openRemoteDocument(using metadata: DocumentMetadata) async {
        eventPublisher.send(.started("Opening \(metadata.documentURL.lastPathComponent)", nil))
        _ = await MainActor.run {
            workspace.open(metadata.documentURL)
        }
        eventPublisher.send(.finished("Opened \(metadata.documentURL.absoluteString)"))
    }

    private func uploadAndAnnotate(url: URL, targetType: DriveUploader.ConversionTarget) async {
        do {
            let account = try await accountSelector.selectAccount(for: url)
            eventPublisher.send(.started("Uploading \(url.lastPathComponent)", account))
            let uploadResult = try await driveUploader.uploadAndConvert(fileURL: url, target: targetType, account: account)
            let metadata = DocumentMetadata(
                documentURL: uploadResult.webViewLink,
                accountID: account.id,
                accountEmail: account.email,
                uploadedAt: Date(),
                uploaderVersion: "0.2.0"
            )
            try DocumentMetadataStore.save(metadata, to: url)
            _ = await MainActor.run {
                workspace.open(uploadResult.webViewLink)
            }
            eventPublisher.send(.finished("Uploaded to Google Docs"))
        } catch AccountSelector.SelectionError.noAccounts {
            eventPublisher.send(.failed(FileRouterError.authenticationMissing))
        } catch AccountSelector.SelectionError.userCancelled {
            eventPublisher.send(.failed(FileRouterError.userCancelled))
        } catch {
            eventPublisher.send(.failed(error))
        }
    }
}

extension FileRouter: @unchecked Sendable {}
