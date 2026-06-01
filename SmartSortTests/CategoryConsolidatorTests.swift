//
//  CategoryConsolidatorTests.swift
//  SmartSortTests
//

import Testing
@testable import SmartSort

struct CategoryConsolidatorTests {

    /// Treats "Invoice"/"Invoices" as near-synonyms; everything else as distinct.
    private let invoiceish: @Sendable (String, String) -> Double = { a, b in
        let group: Set<String> = ["Invoice", "Invoices"]
        if group.contains(a) && group.contains(b) { return 0.1 }
        return a == b ? 0.0 : 1.0
    }

    @Test func mergesNearSynonymsKeepingMostFrequentAsCanonical() {
        // "Invoices" appears twice, "Invoice" once → canonical should be "Invoices".
        let map = CategoryConsolidator(threshold: 0.5, distance: invoiceish)
            .canonicalMap(for: ["Invoices", "Invoices", "Invoice", "Photos"])

        #expect(map["Invoice"] == "Invoices")
        #expect(map["Invoices"] == "Invoices")
        #expect(map["Photos"] == "Photos")
    }

    @Test func keepsDistinctCategoriesSeparate() {
        let exact: @Sendable (String, String) -> Double = { $0 == $1 ? 0 : 1 }
        let map = CategoryConsolidator(threshold: 0.5, distance: exact)
            .canonicalMap(for: ["Apples", "Bananas", "Cherries"])

        #expect(Set(map.values) == ["Apples", "Bananas", "Cherries"])
        #expect(map.count == 3)
    }

    @Test func emptyInputYieldsEmptyMap() {
        #expect(CategoryConsolidator(distance: { _, _ in 1 }).canonicalMap(for: []).isEmpty)
    }
}
