//
//  ShareViewController.swift
//  flymoneyImport
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Copies the shared PDF into the App Group inbox, confirms, and exits — the
/// host app takes over on its next launch or foreground. Links neither
/// SwiftData nor StatementKit; `StatementInbox` is Foundation only.
///
/// It cannot open flymoney itself: `NSExtensionContext.open(_:completionHandler:)`
/// is supported by the Today and iMessage extension points only. That is why
/// the app also registers as a PDF handler — "Open in flymoney" is the row
/// that launches; this one queues.
final class ShareViewController: UIViewController {
    /// Long enough for the confirmation to be read, short enough that the
    /// sheet still feels like a share and not a screen.
    private static let confirmationDuration: Duration = .milliseconds(900)

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await handle() }
    }

    private func handle() async {
        guard let provider = firstPDFAttachment() else {
            await confirm(.failed)
            extensionContext?.cancelRequest(withError: ShareExtensionError.noPDFAttachment)
            return
        }
        do {
            let data = try await loadData(from: provider)
            _ = try StatementInbox.write(data)
            await confirm(.added)
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            await confirm(.failed)
            extensionContext?.cancelRequest(withError: error)
        }
    }

    /// Shows the outcome, then holds it on screen. A blank sheet that vanishes
    /// on its own is indistinguishable from a crash, which is how this was
    /// first reported.
    private func confirm(_ outcome: ShareConfirmationView.Outcome) async {
        show(outcome)
        try? await Task.sleep(for: Self.confirmationDuration)
    }

    private func show(_ outcome: ShareConfirmationView.Outcome) {
        let host = UIHostingController(rootView: ShareConfirmationView(outcome: outcome))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
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
