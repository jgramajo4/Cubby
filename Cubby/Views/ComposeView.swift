//
//  ComposeView.swift
//  Cubby
//

import SwiftUI

struct ComposeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var visibility: Visibility = .priv
    @State private var isPosting = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $text)
                    .focused($focused)
                    .font(.body)
                    .padding(12)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("What's on your mind? Markdown welcome.")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 17)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }

                Divider()

                HStack {
                    Menu {
                        Picker("Visibility", selection: $visibility) {
                            ForEach(Visibility.allCases) { v in
                                Label(v.label, systemImage: v.icon).tag(v)
                            }
                        }
                    } label: {
                        Label(visibility.label, systemImage: visibility.icon)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Text("\(text.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("New memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await post() }
                    } label: {
                        if isPosting { ProgressView() } else { Text("MEMO!").fontWeight(.heavy) }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func post() async {
        isPosting = true
        error = nil
        defer { isPosting = false }
        do {
            try await state.compose(content: text, visibility: visibility)
            dismiss()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
