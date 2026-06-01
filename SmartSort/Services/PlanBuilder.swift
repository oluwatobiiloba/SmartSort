//
//  PlanBuilder.swift
//  SmartSort
//
//  Assembles scanned files + duplicate groups into a reviewable SortPlan.
//

import Foundation

nonisolated struct PlanBuilder {
    /// Build a plan: one move per file into its bucket. Within each duplicate
    /// group the earliest-modified file is kept; the rest are flagged as
    /// duplicates and left unapproved so they aren't moved by default.
    func build(rootFolder: URL, files: [ScannedFile], duplicateGroups: [[URL]]) -> SortPlan {
        let modifiedAt = Dictionary(files.map { ($0.url, $0.modifiedAt) },
                                    uniquingKeysWith: { first, _ in first })

        // Map every flagged duplicate URL to the keeper (original) of its group.
        var duplicateOf: [URL: URL] = [:]
        for group in duplicateGroups {
            let ordered = group.sorted { lhs, rhs in
                let lm = modifiedAt[lhs] ?? .distantFuture
                let rm = modifiedAt[rhs] ?? .distantFuture
                return lm == rm ? lhs.path < rhs.path : lm < rm
            }
            guard let keeper = ordered.first else { continue }
            for duplicate in ordered.dropFirst() { duplicateOf[duplicate] = keeper }
        }

        let moves = files.map { file in
            let original = duplicateOf[file.url]
            return PlannedMove(
                source: file.url,
                destinationBucket: file.bucket,
                suggestedName: file.url.deletingPathExtension().lastPathComponent,
                isDuplicateOf: original,
                approved: original == nil)
        }
        return SortPlan(rootFolder: rootFolder, moves: moves, duplicateGroups: duplicateGroups)
    }
}
