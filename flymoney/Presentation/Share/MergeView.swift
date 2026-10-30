//
//  MergeView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import SwiftUI

struct MergeView: View {
 let viewModel: SharingViewModel
 let onDismiss: () -> Void
 var body: some View {
  if let model = viewModel.budgetReviewModel {
   BudgetReviewView(model: model, onSaved: onDismiss, onCancel: onDismiss)
  } else {
   ContentUnavailableView("Unable to review budget", systemImage: "exclamationmark.triangle")
  }
 }
}
