//
//  MemoDetailView.swift
//  Cubby
//

import SwiftUI

struct MemoDetailView: View {
    @EnvironmentObject var state: AppState
    let memo: Memo

    @State private var comments: [Memo] = []
    @State private var loadingComments = true
    @State private var newComment = ""
    @State private var posting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MemoRow(memo: memo)

                if let reactions = memo.reactions, !reactions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(groupedReactions, id: \.emoji) { item in
                                Pill(text: "\(item.emoji) \(item.count)")
                            }
                        }
                    }
                }

                Divider()

                Text("Comments").font(.headline)

                if loadingComments {
                    ProgressView().frame(maxWidth: .infinity)
                } else if comments.isEmpty {
                    Text("No comments yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(comments) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(c.creatorHandle).font(.caption.weight(.semibold))
                                Spacer()
                                Text(Theme.relative(c.createTime))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(Theme.markdown(c.content)).font(.subheadline)
                        }
                        .padding(12)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Memo")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { composer }
        .task { await loadComments() }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Add a comment…", text: $newComment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                Task { await postComment() }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty || posting)
        }
        .padding(12)
        .background(.bar)
    }

    private struct GroupedReaction { var emoji: String; var count: Int }

    private var groupedReactions: [GroupedReaction] {
        let types = (memo.reactions ?? []).compactMap { $0.reactionType }
        let counts = Dictionary(grouping: types, by: { $0 }).mapValues(\.count)
        return counts.map { GroupedReaction(emoji: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private func loadComments() async {
        guard let client = state.client else { return }
        loadingComments = true
        defer { loadingComments = false }
        comments = (try? await client.listComments(uid: memo.uid)) ?? []
    }

    private func postComment() async {
        guard let client = state.client else { return }
        posting = true
        defer { posting = false }
        let body = newComment
        do {
            let created = try await client.addComment(uid: memo.uid, content: body, visibility: memo.vis)
            comments.append(created)
            newComment = ""
        } catch {
            state.errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
