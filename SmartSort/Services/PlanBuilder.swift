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
                bucket: file.bucket,
                suggestedName: file.url.deletingPathExtension().lastPathComponent,
                isDuplicateOf: original,
                approved: original == nil)
        }
        return SortPlan(rootFolder: rootFolder, moves: moves, duplicateGroups: duplicateGroups)
    }

    /// Overlay AI suggestions onto an existing plan: set each matched move's
    /// category (canonicalized), cleaned name, and confidence. Moves without a
    /// suggestion are left untouched.
    func merging(_ plan: SortPlan,
                 suggestionsByURL: [URL: FileSuggestion],
                 canonical: [String: String]) -> SortPlan {
        var updated = plan
        updated.moves = plan.moves.map { move in
            guard let suggestion = suggestionsByURL[move.source] else { return move }
            var merged = move
            merged.aiCategory = canonical[suggestion.category] ?? suggestion.category
            merged.confidence = suggestion.confidence
            if !suggestion.suggestedBaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                merged.suggestedName = suggestion.suggestedBaseName
            }
            return merged
        }
        return updated
    }
}
