//
//  PlanApplier.swift
//  SmartSort
//
//  Applies a SortPlan (creating bucket folders + moving files) and can fully
//  reverse it from the manifest. Every destructive operation is recorded first.
//

import Foundation

nonisolated struct PlanApplier {
    static let manifestFolderName = ".smartsort"

    /// Create bucket subfolders and move every approved, non-duplicate file into
    /// its bucket. Writes a manifest describing all moves and returns its URL.
    @discardableResult
    func apply(_ plan: SortPlan) throws -> URL {
        let fm = FileManager.default
        var entries: [ManifestEntry] = []

        for move in plan.moves where move.approved && !move.isDuplicate {
            let destinationDir = plan.rootFolder
                .appendingPathComponent(move.destinationFolder, isDirectory: true)
            var destination = destinationDir.appendingPathComponent(move.suggestedName)
            let ext = move.source.pathExtension
            if !ext.isEmpty { destination.appendPathExtension(ext) }

            // Defense in depth: never create folders or move files outside the chosen
            // root, even if upstream sanitization is bypassed (e.g. prompt injection).
            guard Self.isContained(destination, within: plan.rootFolder),
                  Self.isContained(destinationDir, within: plan.rootFolder) else { continue }

            try fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            destination = Self.uniqueDestination(destination)

            try fm.moveItem(at: move.source, to: destination)
            entries.append(ManifestEntry(
                from: move.source.path,
                to: destination.path,
                bucket: move.bucket.rawValue,
                originalName: move.source.lastPathComponent,
                newName: destination.lastPathComponent,
                sha256: nil)) // reserved for integrity checks in a later phase
        }

        let manifest = SortManifest(
            version: SortManifest.currentVersion,
            rootFolder: plan.rootFolder.path,
            createdAt: Date(),
            appName: "SmartSort",
            entries: entries)
        return try Self.writeManifest(manifest, root: plan.rootFolder)
    }

    /// Reverse every move recorded in the manifest, restoring original locations
    /// and cleaning up empty bucket folders and the manifest itself.
    func undo(manifestURL: URL) throws {
        let fm = FileManager.default
        let manifest = try Self.decoder.decode(
            SortManifest.self, from: try Data(contentsOf: manifestURL))

        for entry in manifest.entries.reversed() {
            let current = URL(fileURLWithPath: entry.to)
            let original = URL(fileURLWithPath: entry.from)
            guard fm.fileExists(atPath: current.path) else { continue }   // user moved/deleted it
            guard !fm.fileExists(atPath: original.path) else { continue } // don't clobber
            try fm.createDirectory(at: original.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try fm.moveItem(at: current, to: original)
        }

        // Best-effort cleanup of the folders we created (parents of moved files), then the manifest.
        let createdDirectories = Set(manifest.entries.map {
            URL(fileURLWithPath: $0.to).deletingLastPathComponent().path
        })
        for path in createdDirectories {
            removeIfEmpty(URL(fileURLWithPath: path))
        }
        let rootFolder = URL(fileURLWithPath: manifest.rootFolder)
        try? fm.removeItem(at: manifestURL)
        removeIfEmpty(rootFolder.appendingPathComponent(Self.manifestFolderName, isDirectory: true))
    }

    /// True if `url` resolves to `root` or a path strictly inside it (symlinks
    /// resolved, `..` collapsed) — the guard against path traversal.
    static func isContained(_ url: URL, within root: URL) -> Bool {
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let target = url.resolvingSymlinksInPath().standardizedFileURL.path
        return target == rootPath || target.hasPrefix(rootPath + "/")
    }

    /// Return `url` if free, otherwise the same name with " 2", " 3", … appended.
    static func uniqueDestination(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }

        let directory = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var counter = 2
        while true {
            var candidate = directory.appendingPathComponent("\(base) \(counter)")
            if !ext.isEmpty { candidate.appendPathExtension(ext) }
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            counter += 1
        }
    }

    // MARK: - Manifest I/O

    @discardableResult
    static func writeManifest(_ manifest: SortManifest, root: URL) throws -> URL {
        let fm = FileManager.default
        let directory = root.appendingPathComponent(manifestFolderName, isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter()
            .string(from: manifest.createdAt)
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("manifest-\(stamp).json")
        try encoder.encode(manifest).write(to: url, options: .atomic)
        return url
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func removeIfEmpty(_ directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory.path),
              contents.isEmpty else { return }
        try? fm.removeItem(at: directory)
    }
}
