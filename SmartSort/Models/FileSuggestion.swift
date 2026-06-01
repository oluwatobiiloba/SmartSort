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
    /// How sure the model is. Modeled as an enum (not a free `Double`) so the
    /// preview/routing logic stays deterministic.
    @Generable
    enum Confidence: String, CaseIterable, Equatable, Sendable {
        case low, medium, high
    }

    /// Free-form semantic category folder name (e.g. "Invoices", "Travel
    /// Photos"). Near-synonyms across files are merged by CategoryConsolidator.
    @Guide(description: "A short, human-friendly category folder name in Title Case, e.g. \"Invoices\", \"Travel Photos\", \"Source Code\"")
    let category: String

    @Guide(description: "A clean, descriptive filename WITHOUT the extension")
    let suggestedBaseName: String

    @Guide(description: "How confident you are in this categorization")
    let confidence: Confidence
}
