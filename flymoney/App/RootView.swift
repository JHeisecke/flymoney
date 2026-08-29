//
//  RootView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
	enum TabID: Hashable { case add, history, titles }

	@State private var selection: TabID = .add
	@State private var historyViewModel: HistoryViewModel
	@State private var titlesViewModel: TitlesViewModel
	@State private var addExpenseViewModel: AddExpenseViewModel
	@State private var importCoordinator: StatementImportDrainCoordinator
	let assembly: AppAssembly

	@Environment(\.haptics) private var haptics
	@Environment(\.scenePhase) private var scenePhase
	@State private var showFilePicker = false

	init(assembly: AppAssembly) {
		self.assembly = assembly
        self.historyViewModel = assembly.makeHistoryViewModel()
        self.titlesViewModel = assembly.makeTitlesViewModel()
        self.addExpenseViewModel = assembly.makeAddExpenseViewModel()
        self.importCoordinator = StatementImportDrainCoordinator(makeViewModel: assembly.makeImportStatementViewModel)
	}

	var body: some View {
		@Bindable var importCoordinator = importCoordinator

        TabView(selection: $selection) {
            Tab("Add", systemImage: "plus.circle", value: TabID.add) {
                AddExpenseView(
                    viewModel: addExpenseViewModel, assembly: assembly,
                    onImportRequested: { showFilePicker = true })
            }
            Tab("History", systemImage: "list.bullet", value: TabID.history) {
                HistoryView(viewModel: historyViewModel, assembly: assembly)
            }
            Tab(value: TabID.titles) {
                TitlesView(viewModel: titlesViewModel, assembly: assembly)
            } label: {
                Label(title: { Text(Lexicon.Term.plural.text) }, icon: { Image(systemName: "tag") })
            }
		}
		.onChange(of: selection) { _, newValue in
			if newValue == .history {
				Task { await historyViewModel.load() }
			} else if newValue == .titles {
				Task { await titlesViewModel.load() }
			}
		}
		.tint(Theme.Colors.accent)
		.buttonStyle(.hapticPlain)
		.environment(\.haptics, HapticsManager())
		.onAppear { haptics.prepare() }
		// The picker is raised here, NOT inside the sheet: presenting a sheet
		// whose only content is a second sheet leaves a blank one behind it.
		// The import sheet appears only once a file exists.
		.fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
			if case .success(let url) = result {
				importCoordinator.presentPickedFile(url)
			}
		}
		.sheet(item: $importCoordinator.request) { request in
			ImportStatementHost(
				viewModel: importCoordinator.viewModel ?? assembly.makeImportStatementViewModel(),
				fileURL: request.fileURL,
				onCommitted: { await refreshAfterImport() },
				onDismiss: { importCoordinator.request = nil },
				onViewHistory: {
					importCoordinator.request = nil
					selection = .history
				},
				onPhaseChange: { phase in importCoordinator.phaseDidChange(phase) }
			)
			// One identity per file. Without it SwiftUI reuses the previous
			// presentation's view — and with it the host's `@State` view model,
			// already resolved and already `didStart` — so the second queued
			// file never parses, never reports a phase, never gets removed
			// from the inbox, and re-presents forever.
			.id(request.id)
		}
		// "Open in flymoney" from the share sheet, or any app opening a PDF
		// with flymoney, lands here — this is the only route that actually
		// brings the app to the front with a file. A share extension cannot
		// launch its host app, so its inbox drop waits for `.drain()` below.
		.onOpenURL { url in importCoordinator.presentOpenedFile(url) }
		.task { await importCoordinator.drain() }
		.onChange(of: scenePhase) { _, newPhase in
			if newPhase == .active { Task { await importCoordinator.drain() } }
		}
		.onChange(of: importCoordinator.request) { _, newValue in
			if newValue == nil {
				importCoordinator.requestDidClear()
				Task {
					// Presenting the next queued file's sheet in the same tick
					// as this one's dismissal leaves it visually drawn but
					// input-dead — a SwiftUI `.sheet(item:)` timing quirk.
					// Waiting out the dismiss transition avoids it.
					try? await Task.sleep(for: .milliseconds(400))
					await importCoordinator.drain()
				}
			}
		}
	}

	/// A statement import commits on the Add tab, but its results live in
	/// History and Titles — and Add's own budget indicator can go stale too if
	/// a currently-selected title's spend just changed. `HistoryViewModel`
	/// only re-fetches titles when its cache is empty, so a plain `.load()`
	/// after an import that created new titles would miss them — `reloadTitles()`
	/// resets that cache first. `TitlesViewModel.load()` has no such cache, so
	/// a plain reload is enough there.
	private func refreshAfterImport() async {
		async let history: Void = historyViewModel.reloadTitles()
		async let titles: Void = titlesViewModel.load()
		async let budget: Void = addExpenseViewModel.refreshAfterExternalChange()
		_ = await (history, titles, budget)
	}
}
