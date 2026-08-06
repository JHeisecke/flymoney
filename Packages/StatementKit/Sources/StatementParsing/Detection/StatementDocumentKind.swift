import Foundation

/// A credit-card statement and a bank-account statement are different documents
/// that happen to share a PDF renderer. Kind is decided first, then the bank/
/// layout within that kind — see `StatementKindDetector`.
public enum StatementDocumentKind: String, Codable, Sendable, CaseIterable {
    case creditCard
    case bankAccount
}

/// Kind detection is a small, fixed vocabulary — not a per-profile regex list —
/// because it must stay stable as banks are added. `Débitos`/`Créditos` are
/// deliberately absent from `.bankAccount`: they appear in a *card* statement's
/// movements footer (`Total Créditos: …`) and including them would make card
/// documents score on both kinds.
enum StatementKindSignals {
    static let creditCard: [String] = [
        "MASTERCARD",
        "VISA",
        "TARJETA",
        "LINEA DE CREDITO",
        "N° CUPON",
        "PAGO MINIMO",
        "DEUDA TOTAL",
    ]

    static let bankAccount: [String] = [
        "MOVIMIENTOS DE CUENTA",
        "ESTADO DE CUENTA",
        "NUMERO DE CUENTA",
        "SALDO DIARIO",
        "SALDO ANTERIOR",
        "LINEA DE SOBREGIRO",
    ]
}
