//
//  DuplicateDetector.swift
//  SmartSort
//
//  Exact-duplicate detection via streaming SHA-256 over file contents.
//

import Foundation
import CryptoKit

nonisolated struct DuplicateDetector {
    private static let chunkSize = 1 << 20 // 1 MB

    /// Streaming SHA-256 of a file's contents, as a lowercase hex string.
    /// Reads in chunks so large files don't load fully into memory.
    func hash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: Self.chunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Groups of URLs whose contents are byte-identical. Each returned group has
    /// 2+ members. Files are pre-filtered by size so only same-size files are hashed.
    func exactDuplicateGroups(_ files: [ScannedFile]) throws -> [[URL]] {
        var groups: [[URL]] = []
        let bySize = Dictionary(grouping: files, by: \.size)

        for (_, sameSize) in bySize where sameSize.count > 1 {
            var byHash: [String: [URL]] = [:]
            for file in sameSize {
                byHash[try hash(file.url), default: []].append(file.url)
            }
            for (_, urls) in byHash where urls.count > 1 {
                groups.append(urls)
            }
        }
        return groups
    }
}
