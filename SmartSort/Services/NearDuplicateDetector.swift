//
//  NearDuplicateDetector.swift
//  SmartSort
//
//  Finds visually-similar images (Vision feature prints) and similar documents
//  (NLEmbedding cosine) — files that aren't byte-identical but look alike.
//

import Foundation
import Vision
import NaturalLanguage
import ImageIO

nonisolated struct NearDuplicateDetector {
    /// Feature-print distance at/below which two images are "similar" (lower = closer).
    var imageThreshold: Double = 0.30
    /// Cosine distance at/below which two documents are "similar".
    var documentThreshold: Double = 0.45

    func nearDuplicates(in files: [ScannedFile],
                        signals: [ScannedFile.ID: FileSignals]) async -> [NearDuplicateGroup] {
        var result = await imageGroups(files.filter { $0.bucket == .images })
        result += documentGroups(files, signals: signals)
        return result
    }

    /// Feature-print distance between two images (lower = more similar), or nil
    /// if either image can't be read. Exposed for verification.
    func imageDistance(_ a: URL, _ b: URL) async -> Double? {
        guard let printA = await featurePrint(a), let printB = await featurePrint(b) else { return nil }
        return try? printA.distance(to: printB)
    }

    // MARK: - Images

    private func imageGroups(_ imageFiles: [ScannedFile]) async -> [NearDuplicateGroup] {
        var prints: [(url: URL, print: FeaturePrintObservation)] = []
        for file in imageFiles {
            if let print = await featurePrint(file.url) { prints.append((file.url, print)) }
        }
        let clusters = NearDuplicateGrouper().groups(prints, threshold: imageThreshold) { lhs, rhs in
            (try? lhs.print.distance(to: rhs.print)) ?? .greatestFiniteMagnitude
        }
        return clusters.map { NearDuplicateGroup(kind: .image, urls: $0.map(\.url)) }
    }

    private func featurePrint(_ url: URL) async -> FeaturePrintObservation? {
        guard let image = loadCGImage(url) else { return nil }
        let request = GenerateImageFeaturePrintRequest()
        return try? await request.perform(on: image)
    }

    private func loadCGImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    // MARK: - Documents

    private func documentGroups(_ files: [ScannedFile],
                                signals: [ScannedFile.ID: FileSignals]) -> [NearDuplicateGroup] {
        let textBuckets: Set<FileBucket> = [.pdf, .documents, .code]
        let docs: [(url: URL, text: String)] = files.compactMap { file in
            guard textBuckets.contains(file.bucket),
                  let text = signals[file.id]?.text, !text.isEmpty else { return nil }
            return (file.url, text)
        }
        guard docs.count > 1, let embedding = NLEmbedding.sentenceEmbedding(for: .english) else { return [] }

        let clusters = NearDuplicateGrouper().groups(docs, threshold: documentThreshold) { lhs, rhs in
            embedding.distance(between: lhs.text, and: rhs.text, distanceType: .cosine)
        }
        return clusters.map { NearDuplicateGroup(kind: .document, urls: $0.map(\.url)) }
    }
}
