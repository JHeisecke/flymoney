//
//  ImportFileError.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation

/// Presentation-level, not Domain: describes a file-picker problem, and no
/// use case can raise it.
enum ImportFileError: Error, Equatable {
	/// The picked file could not be read at all.
	case accessDenied
	/// The file was readable but could not be copied into the app container.
	case stagingFailed
}
