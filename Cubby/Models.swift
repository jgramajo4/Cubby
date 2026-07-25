//
//  Models.swift
//  Cubby — a whimsical Memos (usememos.com) client
//
//  Codable types mirroring the Memos v0.29 REST API (/api/v1).
//  Most fields are optional so the app is resilient to version drift.
//

import Foundation

// MARK: - Visibility

enum Visibility: String, Codable, CaseIterable, Identifiable {
    case pub = "PUBLIC"
    case protected = "PROTECTED"
    case priv = "PRIVATE"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pub:       return "Public"
        case .protected: return "Protected"
        case .priv:      return "Private"
        }
    }

    /// SF Symbol used in the compose picker and row footer.
    var icon: String {
        switch self {
        case .pub:       return "globe"
        case .protected: return "person.2.fill"
        case .priv:      return "lock.fill"
        }
    }

    var blurb: String {
        switch self {
        case .pub:       return "Anyone can see this memo."
        case .protected: return "Only signed-in users on your server."
        case .priv:      return "Only you can see this memo."
        }
    }
}

// MARK: - Memo

struct Memo: Codable, Identifiable, Hashable {
    var name: String                 // "memos/{uid}"
    var creator: String?             // "users/{id}"
    var createTime: Date?
    var updateTime: Date?
    var content: String
    var visibility: String?          // raw enum string
    var tags: [String]?
    var pinned: Bool?
    var attachments: [Attachment]?
    var reactions: [Reaction]?
    var snippet: String?

    var id: String { name }

    /// The user-defined id / uuid, e.g. "abc123" from "memos/abc123".
    var uid: String {
        guard let slash = name.firstIndex(of: "/") else { return name }
        return String(name[name.index(after: slash)...])
    }

    var vis: Visibility { Visibility(rawValue: visibility ?? "") ?? .priv }
    var isPinned: Bool { pinned ?? false }

    /// Short creator handle for display, e.g. "users/1" -> "@1".
    var creatorHandle: String {
        guard let creator, let slash = creator.firstIndex(of: "/") else { return "@you" }
        return "@" + creator[creator.index(after: slash)...]
    }
}

// MARK: - Attachment

struct Attachment: Codable, Hashable, Identifiable {
    var name: String                 // "attachments/{id}"
    var filename: String?
    var type: String?                // mime type, e.g. "image/jpeg"
    var externalLink: String?
    var size: String?

    var id: String { name }
    var isImage: Bool { (type ?? "").hasPrefix("image") }

    /// Builds a fetchable URL for this attachment.
    /// Prefers an externalLink; otherwise uses the server's /file route.
    /// NOTE: the /file path shape can vary between Memos versions —
    /// adjust here if your instance serves attachments elsewhere.
    func url(server: URL) -> URL? {
        if let externalLink, !externalLink.isEmpty, let u = URL(string: externalLink) {
            return u
        }
        var u = server.appendingPathComponent("file").appendingPathComponent(name)
        if let filename, !filename.isEmpty {
            u = u.appendingPathComponent(filename)
        }
        return u
    }
}

// MARK: - Reaction

struct Reaction: Codable, Hashable, Identifiable {
    var name: String?
    var creator: String?
    var contentId: String?
    var reactionType: String?        // an emoji, e.g. "👍"

    var id: String { name ?? UUID().uuidString }
}

// MARK: - User

struct MemosUser: Codable, Hashable {
    var name: String?
    var username: String?
    var displayName: String?
    var avatarUrl: String?
}

// MARK: - Response wrappers

struct ListMemosResponse: Codable {
    var memos: [Memo]?
    var nextPageToken: String?
}

struct ListCommentsResponse: Codable {
    var memos: [Memo]?
}

struct APIStatus: Codable {
    var code: Int?
    var message: String?
}

// MARK: - Request bodies

struct CreateMemoBody: Encodable {
    var content: String
    var visibility: String
}

struct PinBody: Encodable {
    var pinned: Bool
}

struct ReactionBody: Encodable {
    struct Inner: Encodable {
        var contentId: String
        var reactionType: String
    }
    var reaction: Inner
}
