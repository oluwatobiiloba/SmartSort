//
//  PlanPreviewView.swift
//  SmartSort
//
//  Preview of the proposed grouping with per-file approval, optional AI
//  enhancement, and the Apply / Undo action bar. Nothing moves until Apply.
//

import SwiftUI

struct PlanPreviewView: View {
    @Bindable var model: SortViewModel
    let plan: SortPlan

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            List {
                if !model.nearDuplicateGroups.isEmpty {
                    Section {
                        ForEach(model.nearDuplicateGroups) { group in
                            NearDuplicateRow(group: group)
                        }
                    } header: {
                        Label("Possible Duplicates (\(model.nearDuplicateGroups.count))",
                              systemImage: "rectangle.on.rectangle.angled")
                    }
                }
                ForEach(model.groupedMoves, id: \.folder) { group in
                    Section {
                        ForEach(group.moves) { move in
                            MoveRow(move: move, isEditable: model.isEditable) { approved in
                                model.setApproved(approved, forMove: move.id)
                            }
                        }
                    } header: {
                        Label("\(group.folder) (\(group.moves.count))",
                              systemImage: bucketIcon(group.bucket))
                    }
                }
            }
            .listStyle(.inset)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if model.isFindingSimilar {
                    ProgressView().controlSize(.small)
                } else if model.canFindSimilar {
                    Button {
                        model.findSimilarFiles()
                    } label: {
                        Label("Find Similar Files", systemImage: "sparkle.magnifyingglass")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.chooseFolder()
                } label: {
                    Label("Choose Another Folder…", systemImage: "folder")
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.rootFolder.lastPathComponent).font(.title2.bold())
                Text(plan.rootFolder.path)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(model.fileCount) files")
                if model.duplicateCount > 0 {
                    Text("\(model.duplicateCount) duplicate\(model.duplicateCount == 1 ? "" : "s")")
                        .foregroundStyle(.orange)
                }
                if model.aiApplied {
                    Label("AI-organized", systemImage: "sparkles").foregroundStyle(.purple)
                }
            }
            .font(.callout)
        }
        .padding()
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 12) {
            switch model.phase {
            case .done:
                Label("Organized — files moved into folders", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                    .keyboardShortcut("z", modifiers: .command)
            case .applying, .categorizing:
                ProgressView().controlSize(.small)
                Text(model.phase == .categorizing ? "Categorizing with AI…" : "Working…")
                    .foregroundStyle(.secondary)
                Spacer()
            default:
                Text("\(model.approvedMoveCount) file\(model.approvedMoveCount == 1 ? "" : "s") will be organized")
                    .foregroundStyle(.secondary)
                Spacer()
                if model.canEnhanceWithAI {
                    Button("Enhance with AI", systemImage: "sparkles") { model.enhanceWithAI() }
                }
                Button {
                    model.apply()
                } label: {
                    Label("Apply", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.phase != .ready || model.approvedMoveCount == 0)
            }
        }
        .padding()
        .background(.bar)
    }

    private func bucketIcon(_ bucket: FileBucket) -> String {
        switch bucket {
        case .images: return "photo"
        case .documents: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .archives: return "archivebox"
        case .media: return "film"
        case .audio: return "music.note"
        case .pdf: return "doc.richtext"
        case .spreadsheets: return "tablecells"
        case .other: return "questionmark.folder"
        }
    }
}

private struct NearDuplicateRow: View {
    let group: NearDuplicateGroup

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: group.kind == .image ? "photo.on.rectangle.angled" : "doc.on.doc")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.urls.map(\.lastPathComponent).joined(separator: ", "))
                    .lineLimit(2)
                Text("\(group.urls.count) similar \(group.kind == .image ? "images" : "documents") — review")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MoveRow: View {
    let move: PlannedMove
    let isEditable: Bool
    let onApprovedChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Include", isOn: Binding(get: { move.approved },
                                            set: { onApprovedChange($0) }))
                .labelsHidden()
                .disabled(!isEditable)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .lineLimit(1).truncationMode(.middle)
                if move.isDuplicate, let original = move.isDuplicateOf {
                    Label("Duplicate of \(original.lastPathComponent)", systemImage: "doc.on.doc")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            if let confidence = move.confidence {
                ConfidenceBadge(confidence)
            }
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            Text(move.destinationFolder)
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .opacity(move.approved ? 1 : 0.5)
    }

    /// Show the AI-cleaned name alongside the original when they differ.
    private var displayName: String {
        let ext = move.source.pathExtension
        let original = move.source.deletingPathExtension().lastPathComponent
        guard move.confidence != nil, move.suggestedName != original else {
            return move.source.lastPathComponent
        }
        return ext.isEmpty ? move.suggestedName : "\(move.suggestedName).\(ext)"
    }
}

private struct ConfidenceBadge: View {
    let confidence: FileSuggestion.Confidence
    init(_ confidence: FileSuggestion.Confidence) { self.confidence = confidence }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch confidence {
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }

    private var color: Color {
        switch confidence {
        case .low: return .orange
        case .medium: return .yellow
        case .high: return .green
        }
    }
}
