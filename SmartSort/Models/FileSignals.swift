//
//  FileSignals.swift
//  SmartSort
//
//  Lightweight, prompt-ready signals extracted per file. These (plus the
//  filename) are what Phase 4 feeds to the model — never whole files.
//

import Foundation

nonisolated struct FileSignals: Sendable, Equatable {
    /// Bounded representative text: PDF text, a document/code head, or image OCR.
    var text: String?
    /// Vision scene/object labels for images, most-confident first.
    var imageLabels: [String]

    init(text: String? = nil, imageLabels: [String] = []) {
        self.text = text
        self.imageLabels = imageLabels
    }

    static let empty = FileSignals()

    var isEmpty: Bool { (text?.isEmpty ?? true) && imageLabels.isEmpty }
}
