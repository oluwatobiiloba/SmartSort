//
//  PlanBuilderTests.swift
//  SmartSortTests
//

import Testing
import Foundation
@testable import SmartSort

struct PlanBuilderTests {

    private func file(_ name: String, bucket: FileBucket, mtime: Date = Date()) -> ScannedFile {
        ScannedFile(url: URL(fileURLWithPath: "/tmp/\(name)"),
                    size: 1, modifiedAt: mtime, contentType: nil, bucket: bucket, sha256: nil)
    }

    @Test func makesOneMovePerFileWithExtensionStripped() {
        let files = [file("note.txt", bucket: .documents), file("pic.png", bucket: .images)]
        let plan = PlanBuilder().build(
            rootFolder: URL(fileURLWithPath: "/tmp"), files: files, duplicateGroups: [])

        #expect(plan.moves.count == 2)
        let note = plan.moves.first { $0.source.lastPathComponent == "note.txt" }
        #expect(note?.suggestedName == "note")
        #expect(note?.bucket == .documents)
        #expect(note?.destinationFolder == "Documents")
        #expect(note?.isDuplicateOf == nil)
        #expect(note?.approved == true)
    }

    @Test func flagsDuplicatesKeepingExactlyOnePerGroup() {
        let a = file("a.txt", bucket: .documents, mtime: Date(timeIntervalSince1970: 100))
        let b = file("b.txt", bucket: .documents, mtime: Date(timeIntervalSince1970: 200))
        let plan = PlanBuilder().build(
            rootFolder: URL(fileURLWithPath: "/tmp"),
            files: [a, b],
            duplicateGroups: [[a.url, b.url]])

        let keepers = plan.moves.filter { $0.isDuplicateOf == nil }
        let flagged = plan.moves.filter { $0.isDuplicateOf != nil }
        #expect(keepers.count == 1)
        #expect(flagged.count == 1)
        #expect(keepers.first?.source == a.url)
        #expect(flagged.first?.source == b.url)
        #expect(flagged.first?.isDuplicateOf == a.url)
        #expect(flagged.first?.approved == false)
    }

    @Test func mergingAppliesSuggestionsAndCanonicalCategories() {
        let a = URL(fileURLWithPath: "/tmp/a.png")
        let b = URL(fileURLWithPath: "/tmp/b.pdf")
        let plan = SortPlan(
            rootFolder: URL(fileURLWithPath: "/tmp"),
            moves: [
                PlannedMove(source: a, bucket: .images, suggestedName: "a"),
                PlannedMove(source: b, bucket: .pdf, suggestedName: "b"),
            ],
            duplicateGroups: [])

        let suggestions: [URL: FileSuggestion] = [
            a: FileSuggestion(category: "Screenshots", suggestedBaseName: "Login Screen", confidence: .high),
            b: FileSuggestion(category: "Invoice", suggestedBaseName: "Acme Invoice", confidence: .medium),
        ]
        let canonical = ["Screenshots": "Screenshots", "Invoice": "Invoices"]

        let merged = PlanBuilder().merging(plan, suggestionsByURL: suggestions, canonical: canonical)

        let ma = try! #require(merged.moves.first { $0.source == a })
        #expect(ma.aiCategory == "Screenshots")
        #expect(ma.destinationFolder == "Screenshots")
        #expect(ma.suggestedName == "Login Screen")
        #expect(ma.confidence == .high)

        let mb = try! #require(merged.moves.first { $0.source == b })
        #expect(mb.aiCategory == "Invoices")        // canonicalized
        #expect(mb.destinationFolder == "Invoices")
        #expect(mb.suggestedName == "Acme Invoice")
        #expect(mb.confidence == .medium)
    }

    @Test func mergingSanitizesMaliciousAICategoryAndName() {
        let a = URL(fileURLWithPath: "/tmp/a.png")
        let plan = SortPlan(
            rootFolder: URL(fileURLWithPath: "/tmp"),
            moves: [PlannedMove(source: a, bucket: .images, suggestedName: "a")],
            duplicateGroups: [])

        // Prompt-injected suggestion trying to escape the root.
        let suggestions: [URL: FileSuggestion] = [
            a: FileSuggestion(category: "../../Library",
                              suggestedBaseName: "../../../etc/passwd",
                              confidence: .high),
        ]
        let canonical = ["../../Library": "../../Library"]

        let merged = PlanBuilder().merging(plan, suggestionsByURL: suggestions, canonical: canonical)
        let move = try! #require(merged.moves.first)

        #expect(!move.destinationFolder.contains("/"))
        #expect(!move.destinationFolder.contains(".."))
        #expect(!move.suggestedName.contains("/"))
        #expect(!move.suggestedName.contains(".."))
    }

    @Test func mergingLeavesUnmatchedMovesUntouched() {
        let a = URL(fileURLWithPath: "/tmp/a.png")
        let plan = SortPlan(
            rootFolder: URL(fileURLWithPath: "/tmp"),
            moves: [PlannedMove(source: a, bucket: .images, suggestedName: "a")],
            duplicateGroups: [])

        let merged = PlanBuilder().merging(plan, suggestionsByURL: [:], canonical: [:])
        let ma = try! #require(merged.moves.first)
        #expect(ma.aiCategory == nil)
        #expect(ma.destinationFolder == "Images")
        #expect(ma.confidence == nil)
    }
}
