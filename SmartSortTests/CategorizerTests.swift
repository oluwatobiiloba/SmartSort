//
//  CategorizerTests.swift
//  SmartSortTests
//
//  Phase 0 de-risk: confirm a typed FileSuggestion comes back from the
//  on-device model. Tests skip gracefully when Apple Intelligence is unavailable.
//

import Testing
import FoundationModels
@testable import SmartSort

struct CategorizerTests {

    @Test func availabilityIsReadable() async {
        let availability = await Categorizer().availability()
        switch availability {
        case .available, .unavailable:
            break // any case is acceptable; we only need the gate to run
        }
    }

    @Test func returnsTypedSuggestionWhenAvailable() async throws {
        let categorizer = Categorizer()
        guard case .available = await categorizer.availability() else {
            // Foundation Models unavailable on this machine — skip, don't fail.
            return
        }

        let suggestion = try await categorizer.suggest(
            forName: "invoice_acme_2026.pdf",
            snippet: "Invoice total $4,200 due net 30 from Acme Corp."
        )

        #expect(!suggestion.suggestedBaseName.isEmpty)
    }
}
