//
//  PlanPreviewView.swift
//  SmartSort
//
//  Sidebar + detail preview of the proposed grouping. The sidebar is a source
//  list of destination folders (plus an "All Files" overview and a "Possible
//  Duplicates" entry); the detail shows the selected folder's moves with an
//  always-visible action bar. Nothing moves until Apply.
//

import SwiftUI

struct PlanPreviewView: View {
    @Bindable var model: SortViewModel
    let plan: SortPlan

    @State private var selection: SidebarItem = .allFiles

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model, selection: $selection)
        } detail: {
            DetailView(model: model, plan: plan, selection: selection)
        }
        // Keep the selection valid when the plan is rebuilt (Undo) or
        // re-categorized by AI (folder names change bucket → category).
        .onChange(of: model.groupedMoves.map(\.folder)) { _, folders in
            if case .folder(let name) = selection, !folders.contains(name) {
                selection = .allFiles
            }
        }
        .onChange(of: model.nearDuplicateGroups.isEmpty) { _, isEmpty in
            if isEmpty, selection == .duplicates { selection = .allFiles }
        }
    }
}

// MARK: - Sidebar

/// Identifies what the detail pane shows. The folder case carries the
/// destination-folder name (the same key `groupedMoves` is grouped by), so a
/// selection survives plan rebuilds as long as that folder still exists.
private enum SidebarItem: Hashable, Identifiable {
    case allFiles
    case folder(String)
    case duplicates

    var id: String {
        switch self {
        case .allFiles: return "__all__"
        case .folder(let name): return "folder:\(name)"
        case .duplicates: return "__duplicates__"
        }
    }
}

private struct SidebarView: View {
    let model: SortViewModel
    @Binding var selection: SidebarItem

    var body: some View {
        List(selection: $selection) {
            Label("All Files", systemImage: "tray.full")
                .badge(model.fileCount)
                .tag(SidebarItem.allFiles)

            Section("Folders") {
                ForEach(model.groupedMoves, id: \.folder) { group in
                    Label(group.folder, systemImage: group.bucket.iconName)
                        .badge(group.moves.count)
                        .tag(SidebarItem.folder(group.folder))
                }
            }

            if !model.nearDuplicateGroups.isEmpty {
                Section("Review") {
                    Label("Possible Duplicates", systemImage: "square.on.square.dashed")
                        .badge(model.nearDuplicateGroups.count)
                        .tag(SidebarItem.duplicates)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    }
}

// MARK: - Detail

private struct DetailView: View {
    let model: SortViewModel
    let plan: SortPlan
    let selection: SidebarItem

    var body: some View {
        detailContent
            .safeAreaInset(edge: .bottom) { ActionBar(model: model) }
            .navigationTitle(plan.rootFolder.lastPathComponent)
            .navigationSubtitle(plan.rootFolder.path)
            .toolbar { toolbarContent }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .allFiles:
            allFilesList
        case .folder(let name):
            // Fall back to the overview if the selected folder no longer exists.
            if let group = model.groupedMoves.first(where: { $0.folder == name }) {
                List { folderSection(group) }
                    .listStyle(.inset)
            } else {
                allFilesList
            }
        case .duplicates:
            NearDuplicatesDetail(groups: model.nearDuplicateGroups)
        }
    }

    private var allFilesList: some View {
        List {
            Section {
                SummaryHeader(model: model)
                    .listRowSeparator(.hidden)
            }
            ForEach(model.groupedMoves, id: \.folder) { group in
                folderSection(group)
            }
        }
        .listStyle(.inset)
    }

    private func folderSection(
        _ group: (folder: String, bucket: FileBucket, moves: [PlannedMove])
    ) -> some View {
        Section {
            ForEach(group.moves) { move in
                FileRow(move: move, isEditable: model.isEditable) { approved in
                    model.setApproved(approved, forMove: move.id)
                }
            }
        } header: {
            Label("\(group.folder) (\(group.moves.count))", systemImage: group.bucket.iconName)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            if model.isFindingSimilar {
                ProgressView().controlSize(.small)
            } else if model.canFindSimilar {
                Button {
                    model.findSimilarFiles()
                } label: {
                    Label("Find Similar Files", systemImage: "magnifyingglass")
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

/// The plain-language summary shown atop the All Files overview.
private struct SummaryHeader: View {
    let model: SortViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(model.fileCount) file\(model.fileCount == 1 ? "" : "s") ready to organize")
                .font(.title3.weight(.semibold))
            HStack(spacing: 14) {
                if model.duplicateCount > 0 {
                    Text("\(model.duplicateCount) duplicate\(model.duplicateCount == 1 ? "" : "s") set aside")
                        .foregroundStyle(.secondary)
                }
                if model.aiApplied {
                    Label("Categorized on device", systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Action bar

private struct ActionBar: View {
    let model: SortViewModel

    var body: some View {
        HStack(spacing: 12) {
            switch model.phase {
            case .done:
                Label("Organized — files moved into folders", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                    .keyboardShortcut("z", modifiers: .command)
            case .applying, .categorizing:
                ProgressView().controlSize(.small)
                Text(model.phase == .categorizing ? "Categorizing on device…" : "Working…")
                    .foregroundStyle(.secondary)
                Spacer()
            default:
                Text("\(model.approvedMoveCount) file\(model.approvedMoveCount == 1 ? "" : "s") will be organized")
                    .foregroundStyle(.secondary)
                Spacer()
                if model.canEnhanceWithAI {
                    Button("Categorize with AI", systemImage: "sparkles") { model.enhanceWithAI() }
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
}

// MARK: - Rows

private struct FileRow: View {
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
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let confidence = move.confidence {
                ConfidenceText(confidence)
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

/// Quiet, monochrome confidence indicator — all three levels read the same
/// neutral gray; the level is conveyed by the word, not by color.
private struct ConfidenceText: View {
    let confidence: FileSuggestion.Confidence
    init(_ confidence: FileSuggestion.Confidence) { self.confidence = confidence }

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }

    private var label: String {
        switch confidence {
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }
}

private struct NearDuplicatesDetail: View {
    let groups: [NearDuplicateGroup]

    var body: some View {
        List {
            Section {
                ForEach(groups) { group in
                    NearDuplicateRow(group: group)
                }
            } header: {
                Text("These files look alike but aren’t identical. Review them yourself — SmartSort never deletes anything for you.")
                    .textCase(nil)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.inset)
    }
}

private struct NearDuplicateRow: View {
    let group: NearDuplicateGroup

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: group.kind == .image ? "photo.on.rectangle.angled" : "doc.on.doc")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.urls.map(\.lastPathComponent).joined(separator: ", "))
                    .lineLimit(2)
                Text("\(group.urls.count) similar \(group.kind == .image ? "images" : "documents")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Shared

private extension FileBucket {
    /// SF Symbol used for this bucket in the sidebar and section headers.
    var iconName: String {
        switch self {
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
