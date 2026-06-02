//
//  NearDuplicateGroup.swift
//  SmartSort
//
//  A set of files that look alike but are NOT byte-identical (visually similar
//  images or similar documents). Advisory only — surfaced for review, never
//  auto-excluded from moves.
//

import Foundation

nonisolated struct NearDuplicateGroup: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable { case image, document }

    let id = UUID()
    var kind: Kind
    var urls: [URL]
}
