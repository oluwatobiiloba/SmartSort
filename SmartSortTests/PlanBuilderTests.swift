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
        #expect(note?.destinationBucket == .documents)
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
        // Earliest-modified (a) is kept; b is flagged as its duplicate and unapproved.
        #expect(keepers.first?.source == a.url)
        #expect(flagged.first?.source == b.url)
        #expect(flagged.first?.isDuplicateOf == a.url)
        #expect(flagged.first?.approved == false)
    }
}
