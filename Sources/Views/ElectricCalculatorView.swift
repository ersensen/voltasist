// ElectricCalculatorView.swift
// VoltAsist
//
// Elektrik Hesap Ana Ekranı — 4 alt sekme ile hesap araçlarına erişim.
// Her sekme renk kodlu ikon ve spring animasyonlu tab geçişleri ile.

import SwiftUI

// MARK: - Hesap Sekmeleri

/// 4 elektrik hesap alt sekmesi
enum CalcTab: Int, CaseIterable {
    case cable        = 0
    case load         = 1
    case lighting     = 2
    case compensation = 3

    var title: String {
        switch self {
        case .cable:        return "Kablo Kesit"
        case .load:         return "Yük / Güç"
        case .lighting:     return "Aydınlatma"
        case .compensation: return "Kompanzasyon"
        }
    }

    var icon: String {
        switch self {
        case .cable:        return "cable.connector"
        case .load:         return "bolt.circle.fill"
        case .lighting:     return "lightbulb.fill"
        case .compensation: return "waveform.path.ecg"
        }
    }

    var color: Color {
        switch self {
        case .cable:        return Color(red: 1.0, green: 0.75, blue: 0.0) // Amber
        case .load:         return Color.orange
        case .lighting:     return Color.cyan
        case .compensation: return Color.purple
        }
    }
}

// MARK: - ElectricCalculatorView

/// Elektrik hesap araçları ana ekranı — premium tab bar ve içerik
struct ElectricCalculatorView: View {

    // MARK: State
    @State private var selectedTab: CalcTab = .cable
    @State private var headerAppeared = false

    // MARK: Tasarım
    private let amber   = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let bgColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {
            // Başlık bölümü
            headerSection

            // Yatay tab seçici
            tabSelector

            // Seçili sekme içeriği
            tabContent
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
        }
        .background(bgColor.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                headerAppeared = true
            }
        }
    }

    // MARK: - Başlık

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(amber.opacity(0.2))
                    .frame(width: 42, height: 42)
                    .shadow(color: amber.opacity(0.5), radius: 8)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(amber)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Elektrik Hesapları")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Text("IEC 60364 · EN 12464-1")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.gray.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .opacity(headerAppeared ? 1.0 : 0.0)
        .offset(y: headerAppeared ? 0 : -10)
    }

    // MARK: - Tab Seçici

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CalcTab.allCases, id: \.rawValue) { tab in
                    calcTabButton(tab: tab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(
            Color(red: 0.06, green: 0.06, blue: 0.09)
                .overlay(
                    Rectangle()
                        .fill(amber.opacity(0.08))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    /// Tek bir tab seçici butonu
    @ViewBuilder
    private func calcTabButton(tab: CalcTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedTab = tab
            }
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.black : Color.gray.opacity(0.65))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? tab.color : Color(red: 0.15, green: 0.15, blue: 0.18))
                    .shadow(color: isSelected ? tab.color.opacity(0.4) : .clear, radius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab İçeriği

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .cable:
            CableCalculatorView()
        case .load:
            LoadCalculatorView()
        case .lighting:
            LightingCalculatorView()
        case .compensation:
            CompensationCalculatorView()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ElectricCalculatorView()
    }
    .preferredColorScheme(.dark)
}
