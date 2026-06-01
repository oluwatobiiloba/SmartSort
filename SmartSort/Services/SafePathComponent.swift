//
//  SafePathComponent.swift
//  SmartSort
//
//  Reduces an arbitrary, untrusted string (e.g. an AI-proposed category or
//  filename derived from file CONTENT, which is prompt-injectable) to a single,
//  filesystem-safe path component. Prevents path traversal / nested-path writes.
//

import Foundation

nonisolated enum SafePathComponent {
    private static let illegal = CharacterSet(charactersIn: "/\\:")
        .union(.controlCharacters)
        .union(.newlines)

    /// Collapse `raw` to one safe path component. Strips path separators, control
    /// characters, and leading dots; rejects "."/".."; caps length. Returns
    /// `fallback` when nothing usable remains.
    static func make(_ raw: String, fallback: String, maxLength: Int = 100) -> String {
        // Replace separators / control chars / newlines with spaces, collapse whitespace.
        var cleaned = raw.components(separatedBy: illegal).joined(separator: " ")
        cleaned = cleaned.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        // Strip leading dots (and any whitespace they expose) so we never produce
        // a hidden file, ".", or "..".
        while let first = cleaned.first, first == "." {
            cleaned.removeFirst()
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        }

        if cleaned.count > maxLength {
            cleaned = String(cleaned.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        }
        return cleaned.isEmpty ? fallback : cleaned
    }
}
