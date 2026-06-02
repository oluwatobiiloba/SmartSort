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
    /// File-type bucket — drives the icon and the deterministic destination.
    var bucket: FileBucket
    /// AI-proposed semantic category folder; nil until AI categorization runs.
    var aiCategory: String?
    /// Model confidence in the AI category; nil for deterministic moves.
    var confidence: FileSuggestion.Confidence?
    /// Base filename WITHOUT extension. Phase 1: original base name; Phase 4: AI-cleaned.
    var suggestedName: String
    /// Non-nil => this file is an exact duplicate of `isDuplicateOf`; excluded from moves by default.
    var isDuplicateOf: URL?
    var approved: Bool = true

    /// The folder files actually move into: the AI category if present, else the bucket folder.
    var destinationFolder: String { aiCategory ?? bucket.folderName }
    var isDuplicate: Bool { isDuplicateOf != nil }
}

nonisolated struct SortPlan: Sendable {
    let rootFolder: URL
    var moves: [PlannedMove]
    /// Exact-hash duplicate groups (each group is 2+ URLs with identical content).
    var duplicateGroups: [[URL]]
    /// Visually/semantically similar (but not identical) files, found on demand.
    var nearDuplicateGroups: [NearDuplicateGroup] = []
}
