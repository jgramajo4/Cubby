//
//  RootView.swift
//  Cubby
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if state.account == nil {
            LoginView()
        } else {
            MainView()
        }
    }
}

struct MainView: View {
    @EnvironmentObject var state: AppState
    @State private var showCompose = false

    var body: some View {
        TabView {
            NavigationStack {
                TimelineView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Server", systemImage: "server.rack") }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showCompose = true
            } label: {
                Label("MEMO!", systemImage: "square.and.pencil")
            }
            .buttonStyle(MemoButtonStyle())
            .padding(.trailing, 18)
            .padding(.bottom, 62)   // sits above the tab bar
        }
        .sheet(isPresented: $showCompose) {
            ComposeView()
        }
    }
}
