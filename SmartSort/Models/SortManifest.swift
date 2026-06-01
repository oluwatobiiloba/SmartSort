//
//  SortManifest.swift
//  SmartSort
//
//  The on-disk record of an applied SortPlan. Written before any move so the
//  operation is always reversible. Lives at <root>/.smartsort/manifest-<date>.json.
//

import Foundation

nonisolated struct ManifestEntry: Codable, Sendable, Hashable {
    let from: String          // original absolute path
    let to: String            // new absolute path after the move
    let bucket: String        // FileBucket.rawValue
    let originalName: String
    let newName: String
    let sha256: String?
}

nonisolated struct SortManifest: Codable, Sendable {
    let version: Int
    let rootFolder: String
    let createdAt: Date
    let appName: String
    let entries: [ManifestEntry]

    static let currentVersion = 1
}
