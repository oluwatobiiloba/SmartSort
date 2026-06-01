//
//  PlanApplierTests.swift
//  SmartSortTests
//
//  The safety-net tests: applying a plan then undoing it must restore the
//  folder to its exact original state.
//

import Testing
import Foundation
@testable import SmartSort

struct PlanApplierTests {

    @Test func applyThenUndoRestoresOriginalState() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("alpha".utf8).write(to: root.appendingPathComponent("a.txt"))
        try Data("an image".utf8).write(to: root.appendingPathComponent("b.png"))
        try Data("print(1)".utf8).write(to: root.appendingPathComponent("c.swift"))

        let before = try snapshot(root)
        let plan = try deterministicPlan(root)
        let applier = PlanApplier()

        let manifestURL = try applier.apply(plan)

        // files were moved into their bucket folders
        #expect(try snapshot(root) != before)
        #expect(exists(root, "Documents/a.txt"))
        #expect(exists(root, "Images/b.png"))
        #expect(exists(root, "Code/c.swift"))
        #expect(!exists(root, "a.txt"))

        try applier.undo(manifestURL: manifestURL)

        #expect(try snapshot(root) == before)
    }

    @Test func skipsUnapprovedMoves() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("keep".utf8).write(to: root.appendingPathComponent("keep.txt"))
        try Data("skip".utf8).write(to: root.appendingPathComponent("skip.txt"))

        var plan = try deterministicPlan(root)
        let i = try #require(plan.moves.firstIndex { $0.source.lastPathComponent == "skip.txt" })
        plan.moves[i].approved = false

        try PlanApplier().apply(plan)

        #expect(exists(root, "Documents/keep.txt"))
        #expect(exists(root, "skip.txt"))            // left in place
        #expect(!exists(root, "Documents/skip.txt"))
    }

    @Test func uniqueDestinationAppendsCounterWhenTaken() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("file.txt")
        try Data("x".utf8).write(to: target)

        #expect(PlanApplier.uniqueDestination(target).lastPathComponent == "file 2.txt")
        // a free path is returned unchanged
        let free = root.appendingPathComponent("free.txt")
        #expect(PlanApplier.uniqueDestination(free).lastPathComponent == "free.txt")
    }

    // MARK: - Helpers

    private func deterministicPlan(_ root: URL) throws -> SortPlan {
        let files = try FolderScanner().scan(root)
        let groups = try DuplicateDetector().exactDuplicateGroups(files)
        return PlanBuilder().build(rootFolder: root, files: files, duplicateGroups: groups)
    }

    private func exists(_ root: URL, _ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path)
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Relative-path + content-hash of every regular file, ignoring `.smartsort`.
    private func snapshot(_ root: URL) throws -> Set<String> {
        let fm = FileManager.default
        let base = root.path
        var out: Set<String> = []
        let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])
        while let url = enumerator?.nextObject() as? URL {
            if url.path.contains("/\(PlanApplier.manifestFolderName)/") { continue }
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let relative = String(url.path.dropFirst(base.count))
            out.insert("\(relative)|\(try DuplicateDetector().hash(url))")
        }
        return out
    }
}
