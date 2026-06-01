//
//  PlanPreviewView.swift
//  SmartSort
//
//  Preview of the proposed grouping with per-file approval, plus the
//  Apply / Undo action bar. Nothing moves until the user taps Apply.
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
                ForEach(model.bucketedMoves, id: \.bucket) { group in
                    Section {
                        ForEach(group.moves) { move in
                            MoveRow(move: move, isEditable: model.isEditable) { approved in
                                model.setApproved(approved, forMove: move.id)
                            }
                        }
                    } header: {
                        Label("\(group.bucket.folderName) (\(group.moves.count))",
                              systemImage: bucketIcon(group.bucket))
                    }
                }
            }
            .listStyle(.inset)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .toolbar {
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
            case .applying:
                ProgressView().controlSize(.small)
                Text("Working…").foregroundStyle(.secondary)
                Spacer()
            default:
                Text("\(model.approvedMoveCount) file\(model.approvedMoveCount == 1 ? "" : "s") will be organized")
                    .foregroundStyle(.secondary)
                Spacer()
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
                Text(move.source.lastPathComponent)
                    .lineLimit(1).truncationMode(.middle)
                if move.isDuplicate, let original = move.isDuplicateOf {
                    Label("Duplicate of \(original.lastPathComponent)", systemImage: "doc.on.doc")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            Text(move.destinationBucket.folderName)
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .opacity(move.approved ? 1 : 0.5)
    }
}
