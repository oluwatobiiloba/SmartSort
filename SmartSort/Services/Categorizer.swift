//
//  Categorizer.swift
//  SmartSort
//
//  Wraps the on-device language model to propose a semantic category + clean
//  filename per file. All AI access is gated through `availability()` so callers
//  can fall back to the deterministic sorter when Apple Intelligence is off.
//

import FoundationModels

actor Categorizer {
    enum Availability: Equatable, Sendable {
        case available
        case unavailable(reason: String)
    }

    private static let instructions = """
    You organize a user's files. Given a filename and a short content excerpt or \
    image labels, choose the best human-friendly category folder and propose a clean, \
    descriptive filename without its extension. Prefer broad, reusable categories \
    (e.g. "Invoices", "Screenshots", "Travel") over hyper-specific ones, and stay \
    consistent so similar files land in the same category.
    """

    /// Runtime gate for on-device model access.
    func availability() -> Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: String(describing: reason))
        }
    }

    /// Categorize and rename a single file from its name + extracted signals.
    func suggest(for file: ScannedFile, signals: FileSignals) async throws -> FileSuggestion {
        let session = LanguageModelSession(instructions: Self.instructions)
        return try await session.respond(to: prompt(for: file, signals: signals),
                                         generating: FileSuggestion.self).content
    }

    /// Categorize many files, capping concurrent model sessions via a sliding
    /// window. Failures on individual files are dropped rather than failing the batch.
    func suggestAll(for files: [ScannedFile],
                    signals: [ScannedFile.ID: FileSignals],
                    maxConcurrent: Int = 2) async -> [ScannedFile.ID: FileSuggestion] {
        guard !files.isEmpty else { return [:] }
        return await withTaskGroup(of: (ScannedFile.ID, FileSuggestion?).self) { group in
            var results: [ScannedFile.ID: FileSuggestion] = [:]
            var next = 0
            let window = min(max(1, maxConcurrent), files.count)

            while next < window {
                let file = files[next]; next += 1
                let fileSignals = signals[file.id] ?? .empty
                group.addTask { (file.id, try? await self.suggest(for: file, signals: fileSignals)) }
            }
            while let (id, suggestion) = await group.next() {
                if let suggestion { results[id] = suggestion }
                if next < files.count {
                    let file = files[next]; next += 1
                    let fileSignals = signals[file.id] ?? .empty
                    group.addTask { (file.id, try? await self.suggest(for: file, signals: fileSignals)) }
                }
            }
            return results
        }
    }

    private func prompt(for file: ScannedFile, signals: FileSignals) -> String {
        var parts = ["Filename: \(file.name)"]
        if let text = signals.text, !text.isEmpty {
            parts.append("Content excerpt:\n\(text)")
        }
        if !signals.imageLabels.isEmpty {
            parts.append("Image labels: \(signals.imageLabels.joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }
}
