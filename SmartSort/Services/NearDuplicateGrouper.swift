//
//  NearDuplicateGrouper.swift
//  SmartSort
//
//  Generic single-linkage clustering: items whose pairwise distance is within a
//  threshold are grouped together (transitively). Used for both visually-similar
//  images and similar documents — the distance metric is supplied by the caller.
//

import Foundation

nonisolated struct NearDuplicateGrouper {
    /// Cluster `items` so any two within `threshold` share a group (single-linkage).
    /// Returns only groups with 2+ members; singletons are dropped.
    func groups<Item>(_ items: [Item],
                      threshold: Double,
                      distance: (Item, Item) -> Double) -> [[Item]] {
        let count = items.count
        guard count > 1 else { return [] }

        var parent = Array(0..<count)
        func root(_ index: Int) -> Int {
            var node = index
            while parent[node] != node {
                parent[node] = parent[parent[node]] // path compression
                node = parent[node]
            }
            return node
        }
        func union(_ a: Int, _ b: Int) {
            let ra = root(a), rb = root(b)
            if ra != rb { parent[ra] = rb }
        }

        for i in 0..<count {
            for j in (i + 1)..<count where distance(items[i], items[j]) <= threshold {
                union(i, j)
            }
        }

        var byRoot: [Int: [Item]] = [:]
        for i in 0..<count { byRoot[root(i), default: []].append(items[i]) }
        return byRoot.values.filter { $0.count > 1 }
    }
}
