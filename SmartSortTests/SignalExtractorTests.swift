//
//  SignalExtractorTests.swift
//  SmartSortTests
//

import Testing
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
@testable import SmartSort

struct SignalExtractorTests {

    @Test func readsTextHeadFromDocument() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("note.txt")
        try Data("The quick brown fox jumps over the lazy dog.".utf8).write(to: url)

        let signals = await SignalExtractor().extract(scanned(url, bucket: .documents, type: .plainText))
        #expect(signals.text?.contains("quick brown fox") == true)
    }

    @Test func truncatesLongText() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("big.txt")
        try Data(String(repeating: "a", count: 10_000).utf8).write(to: url)

        let extractor = SignalExtractor() // maxTextLength = 2000
        let signals = await extractor.extract(scanned(url, bucket: .documents, type: .plainText))
        #expect((signals.text?.count ?? .max) <= extractor.maxTextLength)
    }

    @Test func extractsPDFText() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("invoice.pdf")
        try writePDF(text: "Invoice Total 4200 Acme", to: url)

        let signals = await SignalExtractor().extract(scanned(url, bucket: .pdf, type: .pdf))
        #expect(signals.text?.contains("Invoice") == true)
    }

    @Test func otherBucketProducesEmptySignals() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("blob.bin")
        try Data([0, 1, 2, 3]).write(to: url)

        let signals = await SignalExtractor().extract(scanned(url, bucket: .other, type: nil))
        #expect(signals.isEmpty)
    }

    @Test func ocrReadsRenderedTextFromImage() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("shot.png")
        try writeTextImage("HELLO", to: url)

        let signals = await SignalExtractor().extract(scanned(url, bucket: .images, type: .png))
        #expect(signals.text?.uppercased().contains("HELLO") == true)
    }

    @Test func extractAllCoversEveryFile() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        var files: [ScannedFile] = []
        for i in 0..<6 {
            let url = root.appendingPathComponent("f\(i).txt")
            try Data("contents number \(i)".utf8).write(to: url)
            files.append(scanned(url, bucket: .documents, type: .plainText))
        }

        let signals = await SignalExtractor().extractAll(files, maxConcurrent: 3)
        #expect(signals.count == files.count)
        for file in files {
            #expect(signals[file.id]?.text?.contains("contents number") == true)
        }
    }

    // MARK: - Fixtures

    private func scanned(_ url: URL, bucket: FileBucket, type: UTType?) -> ScannedFile {
        ScannedFile(url: url, size: 1, modifiedAt: Date(), contentType: type, bucket: bucket, sha256: nil)
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writePDF(text: String, to url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        ctx.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        let attributed = NSAttributedString(
            string: text,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: font])
        let line = CTLineCreateWithAttributedString(attributed)
        ctx.textPosition = CGPoint(x: 72, y: 700)
        CTLineDraw(line, ctx)
        ctx.endPDFPage()
        ctx.closePDF()
    }

    private func writeTextImage(_ text: String, to url: URL) throws {
        let width = 600, height = 200
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 90, nil)
        let attributed = NSAttributedString(string: text, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        ctx.textPosition = CGPoint(x: 30, y: 70)
        CTLineDraw(line, ctx)

        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }
}
