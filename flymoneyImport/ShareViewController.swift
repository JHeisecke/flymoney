//
//  ShareViewController.swift
//  flymoneyImport
//
//  Created by Javier Heisecke on 2026-08-06.
//

import UIKit
import UniformTypeIdentifiers

/// No UI. Copies the shared PDF into the App Group inbox and exits — the
/// host app takes over on its next launch or foreground. Links neither
/// SwiftData nor StatementKit; `StatementInbox` is Foundation only.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await handle() }
    }

    private func handle() async {
        guard let provider = firstPDFAttachment() else {
            extensionContext?.cancelRequest(withError: ShareExtensionError.noPDFAttachment)
            return
        }
        do {
            let data = try await loadData(from: provider)
            _ = try StatementInbox.write(data)
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            extensionContext?.cancelRequest(withError: error)
        }
    }

    private func firstPDFAttachment() -> NSItemProvider? {
        for item in extensionContext?.inputItems.compactMap({ $0 as? NSExtensionItem }) ?? [] {
            for attachment in item.attachments ?? [] where attachment.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                return attachment
            }
        }
        return nil
    }

    private func loadData(from provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? ShareExtensionError.noPDFAttachment)
                }
            }
        }
    }
}

enum ShareExtensionError: Error {
    case noPDFAttachment
}
