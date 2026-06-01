//
//  FileSuggestion.swift
//  SmartSort
//
//  AI-proposed organization for a single file, produced by `Categorizer`
//  via Foundation Models guided generation.
//

import FoundationModels

@Generable
struct FileSuggestion: Equatable, Sendable {
    /// Category folders the model may choose from. Kept in sync with `FileBucket`
    /// so an AI suggestion always maps onto a real destination bucket.
    @Generable
    enum Category: String, CaseIterable, Equatable, Sendable {
        case documents, images, code, archives, media, audio, pdfs, spreadsheets, other
    }

    /// How sure the model is. Modeled as an enum (not a free `Double`) so the
    /// preview/routing logic stays deterministic.
    @Generable
    enum Confidence: String, CaseIterable, Equatable, Sendable {
        case low, medium, high
    }

    @Guide(description: "Best category folder for this file")
    let category: Category

    @Guide(description: "A clean, human-readable filename WITHOUT the extension")
    let suggestedBaseName: String

    @Guide(description: "How confident you are in this categorization")
    let confidence: Confidence
}
