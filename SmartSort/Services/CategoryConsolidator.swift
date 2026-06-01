//
//  CategoryConsolidator.swift
//  SmartSort
//
//  Merges near-synonym AI categories ("Invoice" vs "Invoices") into a single
//  canonical name so files don't scatter across almost-identical folders.
//  Similarity defaults to NLEmbedding cosine distance; injectable for testing.
//

import Foundation
import NaturalLanguage

nonisolated struct CategoryConsolidator {
    /// Cosine distance at/below which two category names are treated as the same.
    var threshold: Double
    private let distance: @Sendable (String, String) -> Double

    init(threshold: Double = 0.5, distance: (@Sendable (String, String) -> Double)? = nil) {
        self.threshold = threshold
        self.distance = distance ?? CategoryConsolidator.embeddingDistance
    }

    /// Map every input category (duplicates allowed) to its canonical name.
    /// The most frequent category in each cluster becomes the canonical one.
    func canonicalMap(for categories: [String]) -> [String: String] {
        guard !categories.isEmpty else { return [:] }

        let frequency = categories.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        // Seed clusters with the most frequent categories first so popular names win.
        let ordered = frequency.keys.sorted { lhs, rhs in
            frequency[lhs]! != frequency[rhs]! ? frequency[lhs]! > frequency[rhs]! : lhs < rhs
        }

        var clusters: [(canonical: String, members: [String])] = []
        for category in ordered {
            if let index = clusters.firstIndex(where: { distance($0.canonical, category) <= threshold }) {
                clusters[index].members.append(category)
            } else {
                clusters.append((canonical: category, members: [category]))
            }
        }

        var map: [String: String] = [:]
        for cluster in clusters {
            for member in cluster.members { map[member] = cluster.canonical }
        }
        return map
    }

    // MARK: - Default similarity (NLEmbedding)

    static let embeddingDistance: @Sendable (String, String) -> Double = { lhs, rhs in
        if lhs.caseInsensitiveCompare(rhs) == .orderedSame { return 0 }
        guard let embedding = sharedEmbedding else { return 2 } // unavailable → treat as distinct
        return embedding.distance(between: lhs, and: rhs, distanceType: .cosine)
    }

    private static let sharedEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
}
