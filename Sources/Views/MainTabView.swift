// MainTabView.swift
// VoltAsist
//
// 5 sekmeli premium ana tab bar.
// Koyu arka plan, amber seçili sekme, spring animasyonlu geçişler.

import SwiftUI

// MARK: - Ana Tab Seçimi

/// Uygulamanın 5 ana sekmesi
enum AppTab: Int, CaseIterable {
    case dashboard   = 0
    case calculator  = 1
    case solar       = 2
    case quotes      = 3
    case customers   = 4

    /// Sekme başlığı (Türkçe)
    var title: String {
        switch self {
        case .dashboard:  return "Dashboard"
        case .calculator: return "Hesapla"
        case .solar:      return "Solar"
        case .quotes:     return "Teklif"
        case .customers:  return "Müşteriler"
        }
    }

    /// SF Symbols ikon adı
    var icon: String {
        switch self {
        case .dashboard:  return "house.fill"
        case .calculator: return "bolt.fill"
        case .solar:      return "sun.max.fill"
        case .quotes:     return "doc.text.fill"
        case .customers:  return "person.2.fill"
        }
    }
}

// MARK: - MainTabView

/// Uygulamanın kök görünümü — premium amber tab bar ile
struct MainTabView: View {

    // MARK: State
    /// Seçili sekme indeksi
    @State private var selectedTab: AppTab = .dashboard
    /// Tab geçiş animasyon tetikleyici
    @State private var tabBounce: [AppTab: Bool] = [:]

    // MARK: Environment
    @EnvironmentObject private var persistence: PersistenceService

    // MARK: Tasarım Sabitleri
    private let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    // MARK: Body
    var body: some View {
        ZStack(alignment: .bottom) {
            // İçerik katmanı
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(bgColor.ignoresSafeArea())

            // Özel premium tab bar
            premiumTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Tab İçerikleri

    /// Her sekmeye karşılık gelen view
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .dashboard:
            NavigationStack {
                DashboardView()
            }
        case .calculator:
            NavigationStack {
                ElectricCalculatorView()
            }
        case .solar:
            NavigationStack {
                SolarCalculatorView()
            }
        case .quotes:
            NavigationStack {
                QuoteBuilderView()
            }
        case .customers:
            NavigationStack {
                CustomerListView()
            }
        }
    }

    // MARK: - Premium Tab Bar

    /// Özel tasarımlı amber tab bar
    private var premiumTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                tabBarItem(tab: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            ZStack {
                // Glassmorphic arka plan
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(Color(red: 0.06, green: 0.06, blue: 0.08).opacity(0.85))
                // Üst kenar amber çizgisi
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [amber.opacity(0.6), amber.opacity(0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                    Spacer()
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(amber.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: -4)
        .shadow(color: amber.opacity(0.08), radius: 12, x: 0, y: -2)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tab Bar Kalemi

    /// Tek bir tab bar öğesi
    @ViewBuilder
    private func tabBarItem(tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
                tabBounce[tab] = true
            }
            // Bounce sıfırla
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                tabBounce[tab] = false
            }
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Seçili arka plan pill
                    if isSelected {
                        Capsule()
                            .fill(amber.opacity(0.18))
                            .frame(width: 48, height: 32)
                            .shadow(color: amber.opacity(0.4), radius: 8, x: 0, y: 0)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 20 : 18, weight: .semibold))
                        .foregroundStyle(isSelected ? amber : Color.gray.opacity(0.6))
                        .scaleEffect(tabBounce[tab] == true ? 1.25 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: tabBounce[tab])
                }
                .frame(width: 48, height: 32)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? amber : Color.gray.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(PersistenceService.shared)
        .preferredColorScheme(.dark)
}
