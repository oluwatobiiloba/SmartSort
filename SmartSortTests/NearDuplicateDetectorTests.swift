//
//  NearDuplicateDetectorTests.swift
//  SmartSortTests
//

import Testing
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
@testable import SmartSort

struct NearDuplicateDetectorTests {

    @Test func similarImagesAreCloserThanDifferentImages() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let aBig = root.appendingPathComponent("a_big.png")
        let aSmall = root.appendingPathComponent("a_small.png")
        let b = root.appendingPathComponent("b.png")
        try writeImage("ALPHA", bg: .white, fg: .black, size: 400, to: aBig)
        try writeImage("ALPHA", bg: .white, fg: .black, size: 200, to: aSmall)
        try writeImage("BETA", bg: .black, fg: .white, size: 400, to: b)

        let detector = NearDuplicateDetector()
        let dSame = try #require(await detector.imageDistance(aBig, aSmall))
        let dDifferent = try #require(await detector.imageDistance(aBig, b))

        #expect(dSame < dDifferent)
    }

    @Test func groupsVisuallySimilarImages() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let aBig = root.appendingPathComponent("a_big.png")
        let aSmall = root.appendingPathComponent("a_small.png")
        let b = root.appendingPathComponent("b.png")
        try writeImage("ALPHA", bg: .white, fg: .black, size: 400, to: aBig)
        try writeImage("ALPHA", bg: .white, fg: .black, size: 200, to: aSmall)
        try writeImage("BETA", bg: .black, fg: .white, size: 400, to: b)

        let files = [aBig, aSmall, b].map {
            ScannedFile(url: $0, size: 1, modifiedAt: Date(), contentType: .png, bucket: .images, sha256: nil)
        }
        let groups = await NearDuplicateDetector().nearDuplicates(in: files, signals: [:])
        let imageGroups = groups.filter { $0.kind == .image }

        #expect(imageGroups.contains { Set($0.urls) == [aBig, aSmall] })
        #expect(!imageGroups.contains { $0.urls.contains(b) })
    }

    @Test func groupsSimilarDocuments() async {
        let doc1 = ScannedFile(url: URL(fileURLWithPath: "/tmp/q1.txt"),
                               size: 1, modifiedAt: Date(), contentType: nil, bucket: .documents, sha256: nil)
        let doc2 = ScannedFile(url: URL(fileURLWithPath: "/tmp/q1-copy.txt"),
                               size: 1, modifiedAt: Date(), contentType: nil, bucket: .documents, sha256: nil)
        let doc3 = ScannedFile(url: URL(fileURLWithPath: "/tmp/recipe.txt"),
                               size: 1, modifiedAt: Date(), contentType: nil, bucket: .documents, sha256: nil)
        let report = "The quarterly financial report shows strong revenue growth this period."
        let signals: [ScannedFile.ID: FileSignals] = [
            doc1.id: FileSignals(text: report),
            doc2.id: FileSignals(text: report),
            doc3.id: FileSignals(text: "A recipe for chocolate chip cookies with butter, sugar, and eggs."),
        ]

        let groups = await NearDuplicateDetector().nearDuplicates(in: [doc1, doc2, doc3], signals: signals)
        let docGroups = groups.filter { $0.kind == .document }

        #expect(docGroups.contains { Set($0.urls) == [doc1.url, doc2.url] })
    }

    // MARK: - Fixtures

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private enum Shade { case white, black
        var cgColor: CGColor {
            switch self {
            case .white: return CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            case .black: return CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            }
        }
    }

    private func writeImage(_ label: String, bg: Shade, fg: Shade, size: Int, to url: URL) throws {
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }

        ctx.setFillColor(bg.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, CGFloat(size) / 4, nil)
        let attributed = NSAttributedString(string: label, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: fg.cgColor,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        ctx.textPosition = CGPoint(x: (CGFloat(size) - bounds.width) / 2, y: CGFloat(size) / 2)
        CTLineDraw(line, ctx)

        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }
}
