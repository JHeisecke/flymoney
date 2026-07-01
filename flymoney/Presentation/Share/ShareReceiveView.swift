//
//  ShareReceiveView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ShareReceiveView: View {
	@State private var viewModel: SharingViewModel
	@State private var cameraDenied = false
	@State private var hasScanned = false
	@Environment(\.haptics) private var haptics
	let onDismiss: () -> Void

	init(viewModel: SharingViewModel, onDismiss: @escaping () -> Void) {
		_viewModel = State(initialValue: viewModel)
		self.onDismiss = onDismiss
	}

	var body: some View {
		ZStack {
			RadialGradient(
				colors: [Theme.Colors.surfaceElevatedDark, Theme.Colors.surfaceDeepDark],
				center: .init(x: 0.5, y: 0.3),
				startRadius: 0, endRadius: 600)
				.ignoresSafeArea()

			if cameraDenied {
				VStack(spacing: Theme.Spacing.lg) {
					ShareSheetHeader(
						title: "Receive",
						onCancel: { onDismiss() },
						onDark: true)
					Spacer()
					ContentUnavailableView {
						Label(String(localized: "Camera access needed"), systemImage: "camera.fill")
							.foregroundStyle(Theme.Colors.accent)
					} description: {
						Text(String(localized: "Camera access is required to scan a share code."))
					}
					Button(String(localized: "Open Settings")) {
						Permissions.openSettings()
					}
					.buttonStyle(.borderedProminent)
					.tint(Theme.Colors.accent)
					Spacer()
				}
			} else if hasScanned {
				VStack(spacing: 0) {
					ShareSheetHeader(
						title: "Receive",
						onCancel: { viewModel.cancel(); onDismiss() },
						onDark: true)

					Spacer()

					if case .failed(let reason) = viewModel.phase {
						VStack(spacing: Theme.Spacing.lg) {
							Image(systemName: "exclamationmark.triangle.fill")
								.font(.system(size: 40))
								.foregroundStyle(Theme.Colors.danger)
							Text(reason)
								.font(Theme.Typography.body15)
								.foregroundStyle(Color.white)
								.multilineTextAlignment(.center)
							Button(String(localized: "Try again")) {
								hasScanned = false
								Task { await viewModel.start() }
							}
							.buttonStyle(.borderedProminent)
							.tint(Theme.Colors.accent)
						}
					} else if case .receiving = viewModel.phase {
						ReceiveProgressCard(phase: viewModel.phase, monthName: "June")
							.padding(.horizontal, Theme.Spacing.xxl)
					} else {
						VStack(spacing: Theme.Spacing.md) {
							ProgressView()
								.scaleEffect(1.2)
								.tint(Theme.Colors.accent)
							Text(String(localized: "Connecting…"))
								.font(Theme.Typography.body15)
								.foregroundStyle(Color.white)
						}
					}

					Spacer()

					HStack(spacing: Theme.Spacing.xs) {
						Image(systemName: "lock.fill")
							.font(Theme.Typography.caption12)
						Text(String(localized: "End-to-end encrypted · X25519 · ChaChaPoly"))
							.font(Theme.Typography.body13)
					}
					.foregroundStyle(Theme.Colors.inkQuaternary)
					.padding(.bottom, Theme.Spacing.s42)
				}
			} else {
				VStack(spacing: 0) {
					ShareSheetHeader(
						title: "Receive",
						onCancel: { viewModel.cancel(); onDismiss() },
						onDark: true)

					Spacer().frame(height: Theme.Spacing.s30)

					QRScannerView(
						onCode: { code in
							viewModel.provideScannedQR(code)
							hasScanned = true
							AccessibilityNotification.Announcement(String(localized: "Code found")).post()
							Task { await viewModel.start() }
						},
						onError: { _ in })
						.frame(width: 248, height: 248)
						.clipShape(.rect(cornerRadius: Theme.Radius.xxxl))
						.overlay { ScannerOverlay() }

					Spacer()

					Text(String(localized: "Point at the other phone's code to pair over Bluetooth."))
						.font(Theme.Typography.body14)
						.foregroundStyle(Color(white: 0.66))
						.multilineTextAlignment(.center)
						.padding(.horizontal, Theme.Spacing.xxl)
						.padding(.bottom, Theme.Spacing.s42)
				}
			}
		}
		.preferredColorScheme(.dark)
		.task {
			let granted = await QRScannerViewController.requestCameraAccess()
			cameraDenied = !granted
			if granted {
				AccessibilityNotification.Announcement(String(localized: "Scanning for share code")).post()
			}
		}
		.onChange(of: viewModel.phase) { _, phase in
			switch phase {
			case .awaitingMerge, .done: haptics.success()
			case .failed: haptics.error()
			default: break
			}
		}
	}
}
