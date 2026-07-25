//
//  TimelineView.swift
//  Cubby
//

import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.isLoading && state.memos.isEmpty {
                ProgressView("Loading your timeline…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.memos.isEmpty, let error = state.errorMessage {
                errorState(error)
            } else if state.memos.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(state.memos) { memo in
                        NavigationLink(value: memo) {
                            MemoRow(memo: memo)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .task { await state.loadMoreIfNeeded(current: memo) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await state.delete(memo) }
                            } label: { Label("Delete", systemImage: "trash") }

                            Button {
                                Task { await state.togglePin(memo) }
                            } label: {
                                Label(memo.isPinned ? "Unpin" : "Pin", systemImage: "pin")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Memo.self) { MemoDetailView(memo: $0) }
            }
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await state.refresh() }
        .task { await state.loadInitialIfNeeded() }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await state.refresh() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(Theme.cubby).font(.system(size: 44))
            Text("No memos yet")
                .font(.headline)
            Text("Tap **MEMO!** to capture your first thought.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
