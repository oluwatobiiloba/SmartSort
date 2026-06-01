//
//  DuplicateDetectorTests.swift
//  SmartSortTests
//

import Testing
import Foundation
@testable import SmartSort

struct DuplicateDetectorTests {

    @Test func hashMatchesForIdenticalContentAndDiffersOtherwise() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("a.txt")
        let b = root.appendingPathComponent("b.txt")
        let c = root.appendingPathComponent("c.txt")
        try Data("same".utf8).write(to: a)
        try Data("same".utf8).write(to: b)
        try Data("different".utf8).write(to: c)

        let det = DuplicateDetector()
        #expect(try det.hash(a) == det.hash(b))
        #expect(try det.hash(a) != det.hash(c))
    }

    @Test func hashMatchesKnownSHA256Vector() throws {
        // SHA-256("abc")
        let f = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        try Data("abc".utf8).write(to: f)
        defer { try? FileManager.default.removeItem(at: f) }

        #expect(try DuplicateDetector().hash(f) ==
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func groupsExactDuplicatesOnly() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("dup".utf8).write(to: root.appendingPathComponent("a.txt"))
        try Data("dup".utf8).write(to: root.appendingPathComponent("b.txt"))
        try Data("unique".utf8).write(to: root.appendingPathComponent("c.txt"))

        let files = try FolderScanner().scan(root)
        let groups = try DuplicateDetector().exactDuplicateGroups(files)

        #expect(groups.count == 1)
        #expect(Set(groups[0].map(\.lastPathComponent)) == ["a.txt", "b.txt"])
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
