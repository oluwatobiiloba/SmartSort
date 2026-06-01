//
//  CategorizerTests.swift
//  SmartSortTests
//
//  Confirms a typed FileSuggestion comes back from the on-device model.
//  Tests skip gracefully when Apple Intelligence is unavailable.
//

import Testing
import Foundation
import UniformTypeIdentifiers
@testable import SmartSort

struct CategorizerTests {

    @Test func availabilityIsReadable() async {
        switch await Categorizer().availability() {
        case .available, .unavailable:
            break // any case is acceptable; we only need the gate to run
        }
    }

    @Test func returnsTypedSuggestionWhenAvailable() async throws {
        let categorizer = Categorizer()
        guard case .available = await categorizer.availability() else {
            return // Foundation Models unavailable — skip, don't fail.
        }

        let file = ScannedFile(
            url: URL(fileURLWithPath: "/tmp/invoice_acme_2026.pdf"),
            size: 1, modifiedAt: Date(), contentType: .pdf, bucket: .pdf, sha256: nil)
        let signals = FileSignals(text: "Invoice total $4,200 due net 30 from Acme Corp.")

        let suggestion = try await categorizer.suggest(for: file, signals: signals)

        #expect(!suggestion.suggestedBaseName.isEmpty)
        #expect(!suggestion.category.isEmpty)
    }

    @Test func suggestAllReturnsOnePerFileWhenAvailable() async throws {
        let categorizer = Categorizer()
        guard case .available = await categorizer.availability() else { return }

        let invoice = ScannedFile(url: URL(fileURLWithPath: "/tmp/invoice.pdf"),
                                  size: 1, modifiedAt: Date(), contentType: .pdf, bucket: .pdf, sha256: nil)
        let photo = ScannedFile(url: URL(fileURLWithPath: "/tmp/vacation.jpg"),
                                size: 1, modifiedAt: Date(), contentType: .jpeg, bucket: .images, sha256: nil)
        let signals: [ScannedFile.ID: FileSignals] = [
            invoice.id: FileSignals(text: "Invoice from Acme Corp, total $4,200 due net 30."),
            photo.id: FileSignals(imageLabels: ["beach", "ocean", "sky"]),
        ]

        let result = await categorizer.suggestAll(for: [invoice, photo], signals: signals, maxConcurrent: 2)

        #expect(result.count == 2)
        #expect(result[invoice.id] != nil)
        #expect(result[photo.id] != nil)
    }
}
