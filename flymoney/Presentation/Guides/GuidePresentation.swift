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
					GuideInstructions(symbolName: guide.symbolName, points: guide.summary)
				}
				.navigationTitle(Text(guide.title))
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .topBarTrailing) {
						SheetCloseButton(action: coordinator.dismiss)
					}
				}
				.safeAreaInset(edge: .bottom) {
					Button {
						coordinator.proceed()
					} label: {
						Text("Continue")
							.frame(maxWidth: .infinity)
					}
					.buttonStyle(.accentFilled)
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
