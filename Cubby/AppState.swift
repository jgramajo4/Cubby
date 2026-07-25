//
//  AppState.swift
//  Cubby
//
//  Single source of truth: account, timeline, and the actions the UI calls.
//

import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var account: Account?
    @Published var memos: [Memo] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private var nextPageToken: String?
    private var canLoadMore = true

    var client: MemosClient? {
        guard let account, let url = account.url else { return nil }
        return MemosClient(server: url, token: account.token)
    }

    init() {
        account = AccountStore.load()
    }

    // MARK: Auth

    /// Validates credentials by hitting the API, then persists them.
    func logIn(serverURL raw: String, token: String) async {
        errorMessage = nil
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.lowercased().hasPrefix("http") { trimmed = "https://" + trimmed }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }

        guard let url = URL(string: trimmed), url.host != nil else {
            errorMessage = "That server URL doesn't look right."
            return
        }
        let candidate = Account(serverURL: trimmed, token: token.trimmingCharacters(in: .whitespacesAndNewlines))
        let probe = MemosClient(server: url, token: candidate.token)

        isLoading = true
        defer { isLoading = false }
        do {
            try await probe.ping()
            AccountStore.save(candidate)
            account = candidate
            memos = []
            nextPageToken = nil
            canLoadMore = true
            await refresh()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func logOut() {
        AccountStore.clear()
        account = nil
        memos = []
        nextPageToken = nil
        canLoadMore = true
    }

    // MARK: Timeline

    func refresh() async {
        guard let client else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let resp = try await client.listMemos(pageToken: nil, filter: nil)
            memos = resp.memos ?? []
            nextPageToken = resp.nextPageToken
            canLoadMore = !(resp.nextPageToken ?? "").isEmpty
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadInitialIfNeeded() async {
        guard memos.isEmpty, !isLoading else { return }
        isLoading = true
        await refresh()
        isLoading = false
    }

    func loadMoreIfNeeded(current memo: Memo) async {
        guard let client, canLoadMore, memo.id == memos.last?.id else { return }
        do {
            let resp = try await client.listMemos(pageToken: nextPageToken, filter: nil)
            let incoming = resp.memos ?? []
            let existing = Set(memos.map(\.id))
            memos.append(contentsOf: incoming.filter { !existing.contains($0.id) })
            nextPageToken = resp.nextPageToken
            canLoadMore = !(resp.nextPageToken ?? "").isEmpty
        } catch {
            canLoadMore = false
        }
    }

    // MARK: Mutations

    func compose(content: String, visibility: Visibility) async throws {
        guard let client else { throw APIError.network("Not signed in.") }
        let memo = try await client.createMemo(content: content, visibility: visibility)
        memos.insert(memo, at: pinnedInsertIndex())
    }

    func delete(_ memo: Memo) async {
        guard let client else { return }
        let backup = memos
        memos.removeAll { $0.id == memo.id }
        do { try await client.deleteMemo(uid: memo.uid) }
        catch {
            memos = backup
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func togglePin(_ memo: Memo) async {
        guard let client else { return }
        do {
            let updated = try await client.setPinned(uid: memo.uid, pinned: !memo.isPinned)
            replace(updated)
            memos.sort { ($0.isPinned ? 1 : 0, $0.createTime ?? .distantPast)
                       > ($1.isPinned ? 1 : 0, $1.createTime ?? .distantPast) }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func react(_ memo: Memo, emoji: String = "👍") async {
        guard let client else { return }
        do {
            try await client.react(uid: memo.uid, emoji: emoji)
            // Optimistic: reflect the new reaction immediately.
            var m = memo
            var reactions = m.reactions ?? []
            reactions.append(Reaction(name: UUID().uuidString,
                                      creator: nil,
                                      contentId: memo.name,
                                      reactionType: emoji))
            m.reactions = reactions
            replace(m)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: Helpers

    private func replace(_ memo: Memo) {
        if let i = memos.firstIndex(where: { $0.id == memo.id }) { memos[i] = memo }
    }

    private func pinnedInsertIndex() -> Int {
        memos.firstIndex(where: { !$0.isPinned }) ?? memos.count
    }
}
