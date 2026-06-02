//
//  SortViewModel.swift
//  SmartSort
//
//  Drives the scan → preview → (optional AI) → apply/undo flow. UI-facing state
//  lives here; scanning/hashing/extraction/inference run off the main actor.
//

import Foundation
import Observation

@MainActor
@Observable
final class SortViewModel {
    enum Phase: Equatable { case idle, scanning, categorizing, ready, applying, done }

    private(set) var phase: Phase = .idle
    private(set) var plan: SortPlan?
    private(set) var rootFolder: URL?
    private(set) var manifestURL: URL?
    private(set) var aiAvailable = false
    private(set) var aiApplied = false
    private(set) var isFindingSimilar = false
    private(set) var similarSearchDone = false
    var errorMessage: String?

    private var scannedFiles: [ScannedFile] = []

    /// Refresh whether on-device AI categorization can run (drives the Enhance button).
    func refreshAIAvailability() async {
        aiAvailable = await Categorizer().availability() == .available
    }

    // MARK: - Scanning

    func chooseFolder() {
        guard let url = FolderPicker.pickDirectory() else { return }
        rootFolder = url
        Task { await analyze(url) }
    }

    func analyze(_ root: URL) async {
        phase = .scanning
        plan = nil
        manifestURL = nil
        aiApplied = false
        similarSearchDone = false
        scannedFiles = []
        do {
            let (files, built) = try await Task.detached(priority: .userInitiated) {
                let files = try FolderScanner().scan(root)
                let duplicates = try DuplicateDetector().exactDuplicateGroups(files)
                let plan = PlanBuilder().build(rootFolder: root, files: files, duplicateGroups: duplicates)
                return (files, plan)
            }.value
            scannedFiles = files
            plan = built
            phase = .ready
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    // MARK: - AI enhancement

    /// Extract signals, categorize with the on-device model, consolidate
    /// near-synonym categories, and overlay the results onto the current plan.
    func enhanceWithAI() {
        guard let currentPlan = plan, phase == .ready else { return }
        let targets = scannedFiles.filter { file in
            currentPlan.moves.contains { $0.source == file.url && $0.approved && !$0.isDuplicate }
        }
        guard !targets.isEmpty else { return }

        phase = .categorizing
        Task {
            let signals = await SignalExtractor().extractAll(targets)
            let suggestions = await Categorizer().suggestAll(for: targets, signals: signals)

            let urlByID = Dictionary(uniqueKeysWithValues: targets.map { ($0.id, $0.url) })
            var byURL: [URL: FileSuggestion] = [:]
            for (id, suggestion) in suggestions {
                if let url = urlByID[id] { byURL[url] = suggestion }
            }
            let canonical = CategoryConsolidator().canonicalMap(for: byURL.values.map(\.category))

            plan = PlanBuilder().merging(currentPlan, suggestionsByURL: byURL, canonical: canonical)
            aiApplied = true
            phase = .ready
        }
    }

    // MARK: - Near-duplicate detection

    /// Find visually-similar images and similar documents (advisory; never moves files).
    func findSimilarFiles() {
        guard plan != nil, phase == .ready, !isFindingSimilar else { return }
        isFindingSimilar = true
        let files = scannedFiles
        Task {
            let textBuckets: Set<FileBucket> = [.pdf, .documents, .code]
            let signals = await SignalExtractor().extractAll(files.filter { textBuckets.contains($0.bucket) })
            let groups = await NearDuplicateDetector().nearDuplicates(in: files, signals: signals)
            plan?.nearDuplicateGroups = groups
            isFindingSimilar = false
            similarSearchDone = true
        }
    }

    // MARK: - Apply / Undo

    func apply() {
        guard let plan, phase == .ready else { return }
        phase = .applying
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try PlanApplier().apply(plan)
                }.value
                manifestURL = url
                phase = .done
            } catch {
                errorMessage = error.localizedDescription
                phase = .ready
            }
        }
    }

    func undo() {
        guard let manifestURL, let root = rootFolder else { return }
        phase = .applying
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PlanApplier().undo(manifestURL: manifestURL)
                }.value
                await analyze(root)
            } catch {
                errorMessage = error.localizedDescription
                phase = .done
            }
        }
    }

    // MARK: - Editing

    func setApproved(_ approved: Bool, forMove id: PlannedMove.ID) {
        guard phase == .ready,
              let index = plan?.moves.firstIndex(where: { $0.id == id }) else { return }
        plan?.moves[index].approved = approved
    }

    // MARK: - Derived display state

    /// Moves grouped by destination folder (AI category or bucket), with a
    /// representative bucket for the section icon.
    var groupedMoves: [(folder: String, bucket: FileBucket, moves: [PlannedMove])] {
        guard let plan else { return [] }
        let grouped = Dictionary(grouping: plan.moves, by: \.destinationFolder)
        return grouped.keys.sorted().map { folder in
            let moves = grouped[folder]!.sorted {
                $0.source.lastPathComponent.localizedStandardCompare($1.source.lastPathComponent) == .orderedAscending
            }
            let bucket = Dictionary(grouping: moves, by: \.bucket)
                .max { $0.value.count < $1.value.count }?.key ?? .other
            return (folder, bucket, moves)
        }
    }

    var fileCount: Int { plan?.moves.count ?? 0 }
    var duplicateCount: Int { plan?.moves.filter(\.isDuplicate).count ?? 0 }
    var approvedMoveCount: Int { plan?.moves.filter { $0.approved && !$0.isDuplicate }.count ?? 0 }
    var isEditable: Bool { phase == .ready }
    var canEnhanceWithAI: Bool { phase == .ready && aiAvailable && !aiApplied }
    var canFindSimilar: Bool { phase == .ready && !isFindingSimilar && !similarSearchDone }
    var nearDuplicateGroups: [NearDuplicateGroup] { plan?.nearDuplicateGroups ?? [] }
}
