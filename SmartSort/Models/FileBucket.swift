//
//  FileBucket.swift
//  SmartSort
//
//  Coarse file-type bucket used by the deterministic sorter and as the
//  destination folder for moves. The single source of truth for categories,
//  kept in sync with `FileSuggestion.Category` for the AI path.
//

import Foundation

nonisolated enum FileBucket: String, CaseIterable, Codable, Sendable {
    case images, documents, code, archives, media, audio, pdf, spreadsheets, other

    /// Human-facing destination folder name.
    var folderName: String {
        switch self {
        case .images: return "Images"
        case .documents: return "Documents"
        case .code: return "Code"
        case .archives: return "Archives"
        case .media: return "Media"
        case .audio: return "Audio"
        case .pdf: return "PDFs"
        case .spreadsheets: return "Spreadsheets"
        case .other: return "Other"
        }
    }
}
