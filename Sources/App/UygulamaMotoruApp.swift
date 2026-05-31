// UygulamaMotoruApp.swift
// VoltAsist
//
// Uygulamanın ana giriş noktası.
// MainTabView ile premium tab bar deneyimi sunar.

import SwiftUI

/// VoltAsist uygulamasının giriş noktası.
/// PersistenceService'i EnvironmentObject olarak tüm hiyerarşiye yayar.
@main
public struct UygulamaMotoruApp: App {

    /// Uygulama geneli veri katmanı — ObservableObject singleton
    @StateObject private var persistence = PersistenceService.shared

    public init() {}

    public var body: some Scene {
        WindowGroup {
            // Ana tab view — premium dark mode arayüz
            MainTabView()
                .environmentObject(persistence)
                .preferredColorScheme(.dark)
        }
    }
}
