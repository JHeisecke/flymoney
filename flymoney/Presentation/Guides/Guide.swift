//
//  Guide.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import SwiftUI

enum Guide: String, CaseIterable, Identifiable {
	case firstExpense, recurringExpense, recurringList, shareBudget, receiveBudget, template, category, statement
	var id: String { rawValue }
	var title: LocalizedStringResource {
		switch self {
		case .firstExpense: "First expense and category"
		case .recurringExpense: "Recurring expense"
		case .recurringList: "View recurring expenses"
		case .shareBudget: "Share a budget"
		case .receiveBudget: "Receive a budget"
		case .template: "Load template"
		case .category: "New category"
		case .statement: "Import statement"
		}
	}

	var symbolName: String {
		switch self {
		case .firstExpense: "plus.circle"
		case .recurringExpense: "arrow.clockwise"
		case .recurringList: "arrow.clockwise"
		case .shareBudget: "qrcode"
		case .receiveBudget: "qrcode.viewfinder"
		case .template: "list.bullet.rectangle"
		case .category: "plus"
		case .statement: "doc.badge.plus"
		}
	}

	var summary: [LocalizedStringResource] {
		switch self {
		case .firstExpense:
			[
				"Enter an amount and choose a category.",
				"Save the expense and find it in History.",
			]
		case .recurringExpense:
			[
				"Mark an expense to find it in Recurring expenses.",
				"Record each payment manually.",
			]
		case .recurringList:
			[
				"Find marked expenses grouped by month.",
			]
		case .shareBudget:
			[
				"Share the selected month’s limits by QR and Bluetooth.",
				"Choose whether to include recorded expenses.",
			]
		case .receiveBudget:
			[
				"Scan the other iPhone’s QR code.",
				"Review categories and choose which limits to save.",
			]
		case .template:
			[
				"Choose a profile and starting month.",
				"Review the suggested categories and limits in guaraníes.",
			]
		case .category:
			[
				"Create a category and set a limit from the selected month.",
				"An existing name reuses that category.",
			]
		case .statement:
			[
				"Choose a PDF from GNB, Itaú, or Continental.",
				"Review the transactions and choose which ones to save.",
			]
		}
	}

	var detail: [LocalizedStringResource] {
		switch self {
		case .firstExpense:
			[
				"Open Add and enter the amount.",
				"Choose a category or type a new name to create one when you save.",
				"Save the expense and find it in History.",
				"Open Categories to review or edit your categories.",
			]
		case .recurringExpense:
			[
				"Tap the circular arrow when adding or editing an expense.",
				"Find marked expenses in History under Recurring expenses.",
				"Record each payment manually.",
				"Tap the arrow again to remove the mark.",
			]
		case .recurringList:
			[
				"Tap the circular arrow in History.",
				"Find marked expenses grouped by month.",
				"Record each payment manually.",
			]
		case .shareBudget:
			[
				"Select the month in Categories or History.",
				"Choose whether to include recorded expenses.",
				"Show your QR code to the other iPhone and allow Bluetooth access when prompted.",
			]
		case .receiveBudget:
			[
				"Scan the other iPhone’s QR code.",
				"Allow camera and Bluetooth access when prompted.",
				"Match each received category to one of yours or create a new one.",
				"Keep your current limit or use the received one, then tap Save budget.",
				"The received limit applies from the selected month until the next change.",
			]
		case .template:
			[
				"Choose a profile and starting month.",
				"Review the suggested categories and limits in guaraníes.",
				"Save the budget to apply the selected limits.",
			]
		case .category:
			[
				"Tap Categories at the top of the tab to manage all categories.",
				"An existing name reuses that category.",
				"A limit applies from the selected month until you change it.",
				"Leave the limit blank or enter zero to remove it from that month.",
				"Deleting an expense in the category editor also removes it from History.",
				"Remove all expenses in a category before deleting it.",
			]
		case .statement:
			[
				"Use a PDF with selectable text and make sure the app’s currency is guaraníes (PYG).",
				"GNB supports card statements, card activity, and account statements.",
				"Itaú supports card statements.",
				"Continental supports card statements and account activity.",
				"Correct transactions and choose which ones to save. Refunds reduce the total.",
				"Previously imported transactions start excluded. Possible duplicates stay included for review.",
				"Choose a category for the group. Turn on Remember to use it in future imports.",
			]
		}
	}
}
