//
//  LoginView.swift
//  Cubby
//

import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject var state: AppState
    @State private var server = ""
    @State private var token = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(Theme.cubby).font(.system(size: 56))
                        Text("Cubby").font(.largeTitle.weight(.heavy))
                        Text("A cozy little client for your Memos server.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 16) {
                        field(title: "Server URL",
                              placeholder: "memos.example.com",
                              text: $server,
                              keyboard: .URL)

                        field(title: "Access token",
                              placeholder: "eyJ… (from your account settings)",
                              text: $token,
                              secure: true)

                        Text("Create a token on your server: **Settings → My Account → Access Tokens**, then paste it here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    if let error = state.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await state.logIn(serverURL: server, token: token) }
                    } label: {
                        if state.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Connect")
                        }
                    }
                    .buttonStyle(MemoButtonStyle())
                    .disabled(server.isEmpty || token.isEmpty || state.isLoading)
                    .opacity(server.isEmpty || token.isEmpty ? 0.5 : 1)

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(Theme.accentSoft.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private func field(title: String,
                       placeholder: String,
                       text: Binding<String>,
                       keyboard: UIKeyboardType = .default,
                       secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .padding(12)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
