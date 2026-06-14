// MainTabView.swift
// VoltAsist
//
// 5 sekmeli ana tab bar. Ekran altına sıfır oturan düz tasarım ve amber tema.

import SwiftUI

// MARK: - AppTab

enum AppTab: Int, CaseIterable {
    case dashboard   = 0
    case calculators = 1
    case solar       = 2
    case materials   = 3
    case engineering = 4
    case maintenance = 5

    var title: String {
        switch self {
        case .dashboard:   return "Ana Sayfa"
        case .calculators: return "Hesaplar"
        case .solar:       return "Solar"
        case .materials:   return "Malzeme"
        case .engineering: return "Teklif"
        case .maintenance: return "Bakım Takip"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:   return "house.fill"
        case .calculators: return "bolt.fill"
        case .solar:       return "sun.max.fill"
        case .materials:   return "list.bullet"
        case .engineering: return "doc.text.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {

    @State private var selectedTab: AppTab = .dashboard
    @EnvironmentObject private var persistence: PersistenceService

    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.98)

        // Tab bar üst çizgisi (Subtle amber)
        appearance.shadowColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 0.15)

        let itemAppearance = UITabBarItemAppearance()

        // Seçili sekme görünümü
        itemAppearance.selected.iconColor = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        // Seçilmeyen sekme görünümü
        itemAppearance.normal.iconColor = UIColor.lightGray.withAlphaComponent(0.6)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.lightGray.withAlphaComponent(0.6),
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.icon)
            }
            .tag(AppTab.dashboard)

            NavigationStack {
                ElectricCalculatorView()
            }
            .tabItem {
                Label(AppTab.calculators.title, systemImage: AppTab.calculators.icon)
            }
            .tag(AppTab.calculators)

            NavigationStack {
                SolarCalculatorView()
            }
            .tabItem {
                Label(AppTab.solar.title, systemImage: AppTab.solar.icon)
            }
            .tag(AppTab.solar)

            NavigationStack {
                MaterialListView()
            }
            .tabItem {
                Label(AppTab.materials.title, systemImage: AppTab.materials.icon)
            }
            .tag(AppTab.materials)

            NavigationStack {
                EngineeringPanelView()
            }
            .tabItem {
                Label(AppTab.engineering.title, systemImage: AppTab.engineering.icon)
            }
            .tag(AppTab.engineering)

            NavigationStack {
                MaintenanceTrackingView()
            }
            .tabItem {
                Label(AppTab.maintenance.title, systemImage: AppTab.maintenance.icon)
            }
            .tag(AppTab.maintenance)
        }
        .tint(amber)
        .background(bgColor.ignoresSafeArea())
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(PersistenceService.shared)
        .preferredColorScheme(.dark)
}
