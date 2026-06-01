//
//  ContentView.swift
//  SmartSort
//
//  Root view: routes between the welcome screen, scanning progress, and the plan preview.
//

import SwiftUI

struct ContentView: View {
    @State private var model = SortViewModel()

    var body: some View {
        content
            .frame(minWidth: 640, minHeight: 480)
            .alert("Couldn’t scan that folder",
                   isPresented: Binding(get: { model.errorMessage != nil },
                                        set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            EmptyStateView { model.chooseFolder() }
        case .scanning:
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Scanning…").foregroundStyle(.secondary)
            }
        case .ready, .applying, .done:
            if let plan = model.plan {
                PlanPreviewView(model: model, plan: plan)
            } else {
                EmptyStateView { model.chooseFolder() }
            }
        }
    }
}

#Preview {
    ContentView()
}
