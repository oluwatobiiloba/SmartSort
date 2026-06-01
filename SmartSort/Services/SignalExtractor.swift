//
//  SignalExtractor.swift
//  SmartSort
//
//  Produces FileSignals per file: bounded text (PDF/doc/code/OCR) + image labels.
//  Routes by bucket and runs many files concurrently under a fixed cap.
//  Uses the macOS 26 Swift async Vision API (RecognizeTextRequest / ClassifyImageRequest).
//

import Foundation
import PDFKit
import Vision
import ImageIO

nonisolated struct SignalExtractor {
    var maxTextLength = 2_000
    var maxPDFPages = 5

    /// Extract signals for one file based on its bucket.
    func extract(_ file: ScannedFile) async -> FileSignals {
        switch file.bucket {
        case .images:
            return await imageSignals(file.url)
        case .pdf:
            return FileSignals(text: pdfText(file.url))
        case .documents, .code, .spreadsheets:
            return FileSignals(text: textHead(file.url))
        case .archives, .media, .audio, .other:
            return .empty
        }
    }

    /// Extract signals for many files, capping concurrency via a sliding window.
    func extractAll(_ files: [ScannedFile], maxConcurrent: Int = 4) async -> [ScannedFile.ID: FileSignals] {
        guard !files.isEmpty else { return [:] }
        return await withTaskGroup(of: (ScannedFile.ID, FileSignals).self) { group in
            var results: [ScannedFile.ID: FileSignals] = [:]
            results.reserveCapacity(files.count)

            var next = 0
            let window = min(max(1, maxConcurrent), files.count)
            while next < window {
                let file = files[next]; next += 1
                group.addTask { (file.id, await extract(file)) }
            }
            while let (id, signals) = await group.next() {
                results[id] = signals
                if next < files.count {
                    let file = files[next]; next += 1
                    group.addTask { (file.id, await extract(file)) }
                }
            }
            return results
        }
    }

    // MARK: - Text sources

    private func pdfText(_ url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        var text = ""
        for index in 0..<min(document.pageCount, maxPDFPages) {
            guard let page = document.page(at: index), let pageText = page.string else { continue }
            text += pageText
            if text.count >= maxTextLength { break }
        }
        return clamp(text)
    }

    private func textHead(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        // Read extra bytes so a multi-byte character at the boundary doesn't starve the limit.
        let data = (try? handle.read(upToCount: maxTextLength * 4)) ?? Data()
        guard !data.isEmpty else { return nil }
        return clamp(String(decoding: data, as: UTF8.self))
    }

    // MARK: - Image signals (Vision)

    private func imageSignals(_ url: URL) async -> FileSignals {
        guard let image = loadCGImage(url) else { return .empty }
        async let recognized = recognizeText(image)
        async let labels = classify(image)
        return FileSignals(text: clamp(await recognized), imageLabels: await labels)
    }

    private func recognizeText(_ image: CGImage) async -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        guard let observations = try? await request.perform(on: image) else { return "" }
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private func classify(_ image: CGImage) async -> [String] {
        let request = ClassifyImageRequest()
        guard let observations = try? await request.perform(on: image) else { return [] }
        return observations
            .filter { $0.confidence >= 0.2 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map(\.identifier)
    }

    private func loadCGImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    // MARK: - Helpers

    private func clamp(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(maxTextLength))
    }
}
