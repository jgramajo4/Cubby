//
//  Theme.swift
//  Cubby
//
//  A little whimsy, à la Toot! — bright accent, a bouncy compose button,
//  and lightweight Markdown rendering for memo bodies.
//

import SwiftUI

enum Theme {
    static let accent = Color(red: 0.20, green: 0.55, blue: 1.0)   // friendly blue
    static let accentSoft = Color(red: 0.20, green: 0.55, blue: 1.0).opacity(0.12)
    static let cubby = "🗃️"

    /// Renders inline Markdown (bold, italic, links, code) while preserving
    /// line breaks. Good enough for short memos; swap in a full block
    /// renderer later for headings / code blocks / task lists.
    static func markdown(_ text: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: opts)) ?? AttributedString(text)
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

/// The bouncy "MEMO!" call-to-action, echoing Toot!'s trumpet button.
struct MemoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(Theme.accent)
                    .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Small pill used for tags and visibility.
struct Pill: View {
    let text: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.accentSoft, in: Capsule())
        .foregroundStyle(Theme.accent)
    }
}
