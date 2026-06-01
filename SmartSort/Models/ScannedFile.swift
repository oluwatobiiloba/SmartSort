//
//  ScannedFile.swift
//  SmartSort
//
//  One file discovered by FolderScanner plus the signals extracted so far.
//

import Foundation
import UniformTypeIdentifiers

nonisolated struct ScannedFile: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let size: Int64
    let modifiedAt: Date
    let contentType: UTType?
    var bucket: FileBucket
    var sha256: String?

    var name: String { url.lastPathComponent }
}
