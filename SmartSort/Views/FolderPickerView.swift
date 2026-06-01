//
//  FolderPickerView.swift
//  SmartSort
//
//  Directory selection via NSOpenPanel plus the welcome / empty state.
//

import SwiftUI
import AppKit

@MainActor
enum FolderPicker {
    /// Present an open panel restricted to a single directory. Directory-only
    /// selection is required so the sandbox grant covers the whole subtree.
    static func pickDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Choose a folder for SmartSort to organize."
        return panel.runModal() == .OK ? panel.url : nil
    }
}

struct EmptyStateView: View {
    let onChoose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("SmartSort")
                .font(.largeTitle.bold())
            Text("Pick a folder and SmartSort will preview a tidy, type-based grouping\nand flag exact duplicates — nothing moves until you say so.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: onChoose) {
                Label("Choose Folder…", systemImage: "folder")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding(48)
    }
}

#Preview {
    EmptyStateView(onChoose: {})
        .frame(width: 640, height: 480)
}
