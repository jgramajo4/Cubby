//
//  CubbyApp.swift
//  Cubby — a whimsical iOS client for Memos (usememos.com)
//

import SwiftUI

@main
struct CubbyApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .tint(Theme.accent)
        }
    }
}
