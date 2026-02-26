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
    private let accountSelector: AccountSelector
    private let originalStore = OriginalFileStore.shared
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
            let account = try await accountSelector.selectAccount(for: url)
            let uploadResult = try await driveUploader.uploadAndConvert(fileURL: url, target: targetType, accountID: account.id)
            let storedOriginal = try originalStore.persist(fileURL: url)
            let fileUTType = UTType(filenameExtension: url.pathExtension.lowercased())?.identifier
            let link = GDocLinkFile(
                documentURL: uploadResult.webViewLink,
                originalFilename: url.lastPathComponent,
                uploadedAt: Date(),
                uploaderVersion: "0.1.0",
                accountID: account.id,
                accountEmail: account.email,
                originalBlobHash: storedOriginal.hash,
                originalTypeIdentifier: fileUTType,
                originalFileSize: storedOriginal.fileSize
            )
            _ = try FileUtilities.trashOriginalAndCreateShortcut(originalURL: url, link: link)
            _ = await MainActor.run {
                workspace.open(uploadResult.webViewLink)
            }
            eventPublisher.send(.finished("Rerouted to Google Docs"))
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
