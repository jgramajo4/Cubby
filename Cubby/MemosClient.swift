//
//  MemosClient.swift
//  Cubby
//
//  Thin async wrapper over the Memos REST API.
//  Auth: personal access token (Settings → My Account → Access Tokens on your server).
//

import Foundation

enum APIError: LocalizedError {
    case badURL
    case http(Int, String)
    case network(String)
    case unreachable(String)   // host

    var errorDescription: String? {
        switch self {
        case .badURL:                  return "That server URL doesn't look right."
        case .http(let code, let msg): return "Server error \(code): \(msg)"
        case .network(let msg):        return msg
        case .unreachable(let host):
            return "Can't reach \(host). Is Tailscale connected and your Memos server running?"
        }
    }
}

struct MemosClient {
    let server: URL          // e.g. https://memos.example.com
    let token: String

    private var apiBase: URL { server.appendingPathComponent("api/v1") }

    // MARK: Requests

    private func makeURL(_ path: String, query: [URLQueryItem]) throws -> URL {
        let base = apiBase.appendingPathComponent(path)
        guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIError.badURL
        }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw APIError.badURL }
        return url
    }

    @discardableResult
    private func send(_ path: String,
                      method: String = "GET",
                      query: [URLQueryItem] = [],
                      body: (any Encodable)? = nil) async throws -> Data {
        let url = try makeURL(path, query: query)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)   // implicit existential opening (Swift 5.7+)
        }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let urlError as URLError {
            switch urlError.code {
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
                 .timedOut, .notConnectedToInternet, .networkConnectionLost:
                // Off-tailnet, server down, or DNS not resolving the .ts.net name.
                throw APIError.unreachable(server.host ?? server.absoluteString)
            default:
                throw APIError.network(urlError.localizedDescription)
            }
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard let http = resp as? HTTPURLResponse else {
            throw APIError.network("No response from server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? Self.decoder.decode(APIStatus.self, from: data))?.message
                ?? String(data: data, encoding: .utf8)
                ?? "Unexpected error"
            throw APIError.http(http.statusCode, msg)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try Self.decoder.decode(T.self, from: data) }
        catch { throw APIError.network("Couldn't read the server's response (\(error.localizedDescription)).") }
    }

    // MARK: Endpoints

    /// Home timeline. Pinned first, then newest.
    func listMemos(pageToken: String?, filter: String?) async throws -> ListMemosResponse {
        var q: [URLQueryItem] = [
            .init(name: "pageSize", value: "20"),
            .init(name: "orderBy", value: "pinned desc, create_time desc"),
        ]
        if let pageToken, !pageToken.isEmpty { q.append(.init(name: "pageToken", value: pageToken)) }
        if let filter, !filter.isEmpty { q.append(.init(name: "filter", value: filter)) }
        let data = try await send("memos", query: q)
        return try decode(ListMemosResponse.self, from: data)
    }

    func createMemo(content: String, visibility: Visibility) async throws -> Memo {
        let body = CreateMemoBody(content: content, visibility: visibility.rawValue)
        let data = try await send("memos", method: "POST", body: body)
        return try decode(Memo.self, from: data)
    }

    func deleteMemo(uid: String) async throws {
        try await send("memos/\(uid)", method: "DELETE")
    }

    func setPinned(uid: String, pinned: Bool) async throws -> Memo {
        let data = try await send("memos/\(uid)",
                                  method: "PATCH",
                                  query: [.init(name: "updateMask", value: "pinned")],
                                  body: PinBody(pinned: pinned))
        return try decode(Memo.self, from: data)
    }

    func react(uid: String, emoji: String) async throws {
        let body = ReactionBody(reaction: .init(contentId: "memos/\(uid)", reactionType: emoji))
        try await send("memos/\(uid)/reactions", method: "POST", body: body)
    }

    func listComments(uid: String) async throws -> [Memo] {
        let data = try await send("memos/\(uid)/comments")
        return (try decode(ListCommentsResponse.self, from: data)).memos ?? []
    }

    func addComment(uid: String, content: String, visibility: Visibility) async throws -> Memo {
        let body = CreateMemoBody(content: content, visibility: visibility.rawValue)
        let data = try await send("memos/\(uid)/comments", method: "POST", body: body)
        return try decode(Memo.self, from: data)
    }

    /// Cheap call used to validate credentials at login.
    func ping() async throws {
        _ = try await send("memos", query: [.init(name: "pageSize", value: "1")])
    }

    // MARK: Decoder

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            if let date = isoFractional.date(from: s) ?? isoPlain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(s)")
        }
        return d
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
