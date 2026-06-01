//
//  SortPlan.swift
//  SmartSort
//
//  A proposed reorganization the user reviews before anything touches disk.
//

import Foundation

nonisolated struct PlannedMove: Identifiable, Hashable, Sendable {
    let id = UUID()
    let source: URL
    var destinationBucket: FileBucket
    /// Base filename WITHOUT extension. Phase 1: the original base name.
    /// Phase 4: an AI-cleaned name.
    var suggestedName: String
    /// Non-nil => this file is an exact duplicate of `isDuplicateOf`; excluded from moves by default.
    var isDuplicateOf: URL?
    var approved: Bool = true

    var isDuplicate: Bool { isDuplicateOf != nil }
}

nonisolated struct SortPlan: Sendable {
    let rootFolder: URL
    var moves: [PlannedMove]
    /// Exact-hash duplicate groups (each group is 2+ URLs with identical content).
    var duplicateGroups: [[URL]]
}
