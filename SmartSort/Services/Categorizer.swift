//
//  Categorizer.swift
//  SmartSort
//
//  Wraps the on-device language model to propose a category + clean filename.
//  All AI access is gated through `availability()` so callers can fall back to
//  the deterministic sorter when Apple Intelligence is unavailable.
//

import FoundationModels

actor Categorizer {
    enum Availability: Equatable, Sendable {
        case available
        case unavailable(reason: String)
    }

    /// Runtime gate for on-device model access. Map the framework's availability
    /// onto a small value type so the rest of the app never imports the reason enum.
    func availability() -> Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: String(describing: reason))
        }
    }

    /// Ask the model to categorize and rename a single file from light signals
    /// (its filename plus a short content snippet). Throws if generation fails.
    func suggest(forName name: String, snippet: String) async throws -> FileSuggestion {
        let session = LanguageModelSession(
            instructions: """
            You organize a user's files. Given a filename and a short content snippet, \
            choose the best category folder and propose a clean, descriptive filename \
            without its extension. Be concise and consistent.
            """
        )
        let prompt = """
        Filename: \(name)
        Content snippet: \(snippet)
        """
        return try await session.respond(to: prompt, generating: FileSuggestion.self).content
    }
}
