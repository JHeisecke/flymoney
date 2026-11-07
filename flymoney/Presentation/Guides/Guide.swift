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
	var summary: LocalizedStringResource {
		switch self {
		case .firstExpense: "Enter an amount and choose a category or type a new name. Save the expense, then find it in History."
		case .recurringExpense: "Mark this expense to find it in Recurring expenses. Each payment is recorded manually."
		case .recurringList: "See expenses marked as recurring, grouped by month."
		case .shareBudget: "Share the month's limits using QR and Bluetooth. You can also include recorded expenses."
		case .receiveBudget: "Scan the other iPhone's QR code. You can review categories and choose which limits to save."
		case .template: "Choose a profile and starting month. The template suggests categories and limits in guaraníes."
		case .category: "Create a category and set a limit from the selected month. An existing name reuses that category."
		case .statement: "Choose a compatible bank PDF. You can review, correct, and select transactions before saving."
		}
	}
	var detail: LocalizedStringResource {
		switch self {
		case .firstExpense: "In Add, enter an amount and choose an existing category or type a new name. Saving creates the category when needed. Find the expense in History. Open Categories to review or edit your categories."
		case .recurringExpense: "Mark an expense as recurring when adding or editing it. Each payment is entered manually. Tap the recurring button again to remove the mark."
		case .recurringList: "In History, open recurring expenses to see marked expenses grouped by month. Each payment is entered manually."
		case .shareBudget: "Share limits for the selected month using a QR code and Bluetooth. You can include that month's expenses, or share limits alone. Allow the requested Bluetooth access to transfer the budget."
		case .receiveBudget: "Scan the sender's QR code and allow camera and Bluetooth access when requested. Match each received category to an existing one or create a new category.\n\nChoose whether to keep your current limit or use the received limit, then tap Save budget. The received limit takes effect from the selected month until the next change."
		case .template: "Choose a profile and starting month. The template suggests categories and limits in guaraníes for you to review and apply."
		case .category: "Tap Categories at the top of the Categories tab to manage all categories. An existing name reuses that category. A limit applies from the chosen month until the next change. Leave it blank or enter zero to remove the limit from that month.\n\nWhen you delete an expense from the category editor, it disappears from History. To delete a category, first remove all of its expenses."
		case .statement: "Choose a PDF with selectable text. GNB supports card statements, card activity, and account statements. Itaú supports card statements. Continental supports card and account statements. These formats are imported in guaraníes. FlyMoney uses the currency of your device region, which needs to match.\n\nReview and correct transactions and choose which ones to save. Refunds reduce the total. Already imported transactions start excluded. Possible duplicates start included and can be excluded during review.\n\nChoose a category for the whole group. Turn on Remember to use the same category in future imports."
		}
	}
}
