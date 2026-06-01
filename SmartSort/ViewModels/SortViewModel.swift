//
//  SortViewModel.swift
//  SmartSort
//
//  Drives the scan → preview → apply/undo flow. UI-facing state lives here;
//  the heavy scanning/hashing/moving runs off the main actor.
//

import Foundation
import Observation

@MainActor
@Observable
final class SortViewModel {
    enum Phase: Equatable { case idle, scanning, ready, applying, done }

    private(set) var phase: Phase = .idle
    private(set) var plan: SortPlan?
    private(set) var rootFolder: URL?
    private(set) var manifestURL: URL?
    var errorMessage: String?

    // MARK: - Scanning

    /// Prompt for a folder, then scan + analyze it.
    func chooseFolder() {
        guard let url = FolderPicker.pickDirectory() else { return }
        rootFolder = url
        Task { await analyze(url) }
    }

    /// Scan the folder, detect exact duplicates, and build a reviewable plan.
    func analyze(_ root: URL) async {
        phase = .scanning
        plan = nil
        manifestURL = nil
        do {
            let built = try await Task.detached(priority: .userInitiated) {
                let files = try FolderScanner().scan(root)
                let duplicates = try DuplicateDetector().exactDuplicateGroups(files)
                return PlanBuilder().build(rootFolder: root, files: files, duplicateGroups: duplicates)
            }.value
            plan = built
            phase = .ready
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    // MARK: - Apply / Undo

    /// Move every approved, non-duplicate file into its bucket and remember the
    /// manifest so the whole operation can be reversed.
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

    /// Reverse the last apply, then re-scan the restored folder.
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

    /// Moves grouped by destination bucket, in a stable display order.
    var bucketedMoves: [(bucket: FileBucket, moves: [PlannedMove])] {
        guard let plan else { return [] }
        let grouped = Dictionary(grouping: plan.moves, by: \.destinationBucket)
        return FileBucket.allCases.compactMap { bucket in
            guard let moves = grouped[bucket], !moves.isEmpty else { return nil }
            let sorted = moves.sorted {
                $0.source.lastPathComponent.localizedStandardCompare($1.source.lastPathComponent) == .orderedAscending
            }
            return (bucket, sorted)
        }
    }

    var fileCount: Int { plan?.moves.count ?? 0 }
    var duplicateCount: Int { plan?.moves.filter(\.isDuplicate).count ?? 0 }
    var approvedMoveCount: Int { plan?.moves.filter { $0.approved && !$0.isDuplicate }.count ?? 0 }
    var isEditable: Bool { phase == .ready }
}
