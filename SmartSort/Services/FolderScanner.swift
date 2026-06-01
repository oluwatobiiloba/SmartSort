//
//  FolderScanner.swift
//  SmartSort
//
//  Enumerates a folder one level deep and classifies each file into a FileBucket.
//

import Foundation
import UniformTypeIdentifiers

nonisolated struct FolderScanner {
    private static let keys: Set<URLResourceKey> = [
        .contentTypeKey, .fileSizeKey, .contentModificationDateKey, .isRegularFileKey,
    ]

    /// Enumerate `root` one level deep (no subdirectories, no hidden files),
    /// returning a ScannedFile per regular file with its bucket assigned.
    func scan(_ root: URL) throws -> [ScannedFile] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(Self.keys),
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])

        return try urls.compactMap { url -> ScannedFile? in
            let values = try url.resourceValues(forKeys: Self.keys)
            guard values.isRegularFile == true else { return nil } // skip dirs, packages, symlinks
            let type = values.contentType
            return ScannedFile(
                url: url,
                size: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? Date(),
                contentType: type,
                bucket: Self.bucket(for: type),
                sha256: nil)
        }
    }

    /// Map a file's UTType onto a coarse destination bucket. Order matters:
    /// more specific conformances are checked first (source code before plain text).
    static func bucket(for type: UTType?) -> FileBucket {
        guard let type else { return .other }
        if type.conforms(to: .image) { return .images }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .movie) { return .media }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .sourceCode) { return .code }
        if type.conforms(to: .spreadsheet) { return .spreadsheets }
        if type.conforms(to: .archive) { return .archives }
        if type.conforms(to: .text) { return .documents }
        return .other
    }
}
