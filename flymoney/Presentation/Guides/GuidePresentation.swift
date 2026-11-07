//
//  GuidePresentation.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import SwiftUI

struct GuidePresentation: ViewModifier {
	@Bindable var coordinator: GuideCoordinator

	func body(content: Content) -> some View {
		content.sheet(item: $coordinator.presented, onDismiss: { coordinator.didDismiss() }) { guide in
			NavigationStack {
				ScrollView {
					Text(guide.summary)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding()
				}
				.navigationTitle(Text(guide.title))
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Close") { coordinator.dismiss() }
					}
				}
				.safeAreaInset(edge: .bottom) {
					Button {
						coordinator.proceed()
					} label: {
						Text("Continue")
							.frame(maxWidth: .infinity, minHeight: 44)
							.contentShape(.rect)
					}
					.buttonStyle(.borderedProminent)
					.padding()
					.background(.regularMaterial)
				}
			}
			.presentationDetents([.medium, .large])
			.presentationDragIndicator(.visible)
			.onAppear { coordinator.appeared(guide) }
		}
	}
}
