//
//  SettingsView.swift
//  Cubby
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var confirmLogout = false

    var body: some View {
        List {
            Section("Server") {
                LabeledContent("Host", value: state.account?.host ?? "—")
                LabeledContent("Memos", value: "\(state.memos.count) loaded")
            }

            Section {
                Button(role: .destructive) {
                    confirmLogout = true
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Theme.cubby) Cubby").font(.headline)
                    Text("An unofficial client for Memos (usememos.com).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Server")
        .confirmationDialog("Sign out of this server?",
                            isPresented: $confirmLogout,
                            titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { state.logOut() }
            Button("Cancel", role: .cancel) { }
        }
    }
}
