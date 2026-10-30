//
//  BudgetFlow.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

/// An explicit expense-only boundary; future income support must opt in.
enum BudgetFlow: String, Codable, Sendable { case expense }
