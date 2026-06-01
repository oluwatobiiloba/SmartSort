//
//  FolderScannerTests.swift
//  SmartSortTests
//

import Testing
import Foundation
import UniformTypeIdentifiers
@testable import SmartSort

struct FolderScannerTests {

    @Test func bucketsCommonTypes() {
        #expect(FolderScanner.bucket(for: .png) == .images)
        #expect(FolderScanner.bucket(for: .jpeg) == .images)
        #expect(FolderScanner.bucket(for: .pdf) == .pdf)
        #expect(FolderScanner.bucket(for: .swiftSource) == .code)
        #expect(FolderScanner.bucket(for: .mpeg4Movie) == .media)
        #expect(FolderScanner.bucket(for: .mp3) == .audio)
        #expect(FolderScanner.bucket(for: .zip) == .archives)
        #expect(FolderScanner.bucket(for: .plainText) == .documents)
        #expect(FolderScanner.bucket(for: nil) == .other)
    }

    @Test func folderNamesAreHumanFacing() {
        #expect(FileBucket.pdf.folderName == "PDFs")
        #expect(FileBucket.images.folderName == "Images")
        #expect(FileBucket.other.folderName == "Other")
    }

    @Test func scanReturnsRegularFilesOneLevelDeepSkippingDirsAndHidden() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try Data("hi".utf8).write(to: root.appendingPathComponent("note.txt"))
        try Data("img".utf8).write(to: root.appendingPathComponent("pic.png"))
        try Data("h".utf8).write(to: root.appendingPathComponent(".hidden"))
        let sub = root.appendingPathComponent("nested")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("deep".utf8).write(to: sub.appendingPathComponent("deep.txt"))

        let files = try FolderScanner().scan(root)
        let names = Set(files.map(\.name))

        #expect(names == ["note.txt", "pic.png"])
        #expect(files.first { $0.name == "pic.png" }?.bucket == .images)
        #expect(files.first { $0.name == "note.txt" }?.bucket == .documents)
    }
}
