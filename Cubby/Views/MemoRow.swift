//
//  MemoRow.swift
//  Cubby
//

import SwiftUI

struct MemoRow: View {
    @EnvironmentObject var state: AppState
    let memo: Memo

    private var serverURL: URL? { state.account?.url }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                if memo.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(memo.creatorHandle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: memo.vis.icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Theme.relative(memo.createTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Body
            Text(Theme.markdown(memo.content))
                .font(.body)
                .textSelection(.enabled)

            // Image attachments
            if let images = memo.attachments?.filter(\.isImage), !images.isEmpty {
                attachmentGrid(images)
            }

            // Tags
            if let tags = memo.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { Pill(text: "#\($0)") }
                    }
                }
            }

            // Footer actions
            HStack(spacing: 22) {
                actionButton("bubble.left", label: reactionSummary) { }   // opens detail via row tap
                    .allowsHitTesting(false)
                Button { Task { await state.react(memo) } } label: {
                    Label("React", systemImage: "hand.thumbsup")
                }
                Button { Task { await state.togglePin(memo) } } label: {
                    Label(memo.isPinned ? "Unpin" : "Pin",
                          systemImage: memo.isPinned ? "pin.slash" : "pin")
                }
                Spacer()
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .labelStyle(.iconOnly)
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }

    private var reactionSummary: String {
        let count = memo.reactions?.count ?? 0
        return count > 0 ? "\(count)" : ""
    }

    private func actionButton(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system)
            if !label.isEmpty { Text(label) }
        }
    }

    @ViewBuilder
    private func attachmentGrid(_ images: [Attachment]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
        LazyVGrid(columns: images.count == 1 ? [GridItem(.flexible())] : columns, spacing: 6) {
            ForEach(images) { att in
                if let server = serverURL, let url = att.url(server: server) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Color(.secondarySystemBackground)
                                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                        default:
                            Color(.secondarySystemBackground)
                                .overlay(ProgressView())
                        }
                    }
                    .frame(height: images.count == 1 ? 200 : 130)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
