// MainTabView.swift
// VoltAsist
//
// 5 sekmeli ana tab bar. Safe area'ya uyumlu, amber tema, spring animasyon.

import SwiftUI

// MARK: - AppTab

enum AppTab: Int, CaseIterable {
    case dashboard   = 0
    case calculator  = 1
    case solar       = 2
    case materials   = 3
    case engineering = 4

    var title: String {
        switch self {
        case .dashboard:   return "Ana Sayfa"
        case .calculator:  return "Hesapla"
        case .solar:       return "Solar"
        case .materials:   return "Malzeme"
        case .engineering: return "Panel"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:   return "house.fill"
        case .calculator:  return "bolt.fill"
        case .solar:       return "sun.max.fill"
        case .materials:   return "shippingbox.fill"
        case .engineering: return "chart.bar.doc.horizontal.fill"
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {

    @State private var selectedTab: AppTab = .dashboard
    @State private var bounce: [AppTab: Bool] = [:]

    @EnvironmentObject private var persistence: PersistenceService

    private let amber  = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bg     = Color(red: 0.06, green: 0.06, blue: 0.09)
    private let tabBG  = Color(red: 0.08, green: 0.08, blue: 0.12)

    var body: some View {
        ZStack(alignment: .bottom) {
            // İçerik — NavigationStack her sekme için ayrı
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating tab bar
            tabBar
        }
        .background(bg.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Tab İçeriği

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .dashboard:
            NavigationStack { DashboardView() }
                .transition(.opacity)
        case .calculator:
            NavigationStack { ElectricCalculatorView() }
                .transition(.opacity)
        case .solar:
            NavigationStack { SolarCalculatorView() }
                .transition(.opacity)
        case .materials:
            NavigationStack { MaterialListView() }
                .transition(.opacity)
        case .engineering:
            NavigationStack { EngineeringPanelView() }
                .transition(.opacity)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                tabItem(tab)
            }
        }
        // İç padding
        .padding(.top, 10)
        .padding(.bottom, safeBottomInset + 8)
        .background(
            ZStack {
                // Glass arka plan
                tabBG.opacity(0.96)
                // Üst amber çizgisi
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [amber.opacity(0.5), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.8)
                    Spacer()
                }
            }
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(amber.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: -6)
        .shadow(color: amber.opacity(0.06), radius: 16, x: 0, y: -2)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Tek Tab Kalemi

    private func tabItem(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            guard selectedTab != tab else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                selectedTab = tab
                bounce[tab] = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                bounce[tab] = false
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(amber.opacity(0.15))
                            .frame(width: 44, height: 30)
                            .shadow(color: amber.opacity(0.35), radius: 6)
                    }
                    Image(systemName: tab.icon)
                        .font(.system(size: 19, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? amber : Color.gray.opacity(0.5))
                        .scaleEffect(bounce[tab] == true ? 1.22 : 1.0)
                        .animation(
                            .spring(response: 0.22, dampingFraction: 0.55),
                            value: bounce[tab]
                        )
                }
                .frame(height: 30)

                Text(tab.title)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? amber : Color.gray.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Safe Area

    private var safeBottomInset: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom) ?? 0
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(PersistenceService.shared)
        .preferredColorScheme(.dark)
}
