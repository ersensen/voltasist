// ViewExtensions.swift
// VoltAsist
//
// Global View ve TextField genişletmeleri (extensions).
// Cam efekti kart stili ve özelleştirilmiş textfield giriş alanı tasarımı.

import SwiftUI

extension View {
    /// Glassmorphism kart stili — amber kenarlık varsayılan
    func glassCard(borderColor: Color = Color(red: 1.0, green: 0.75, blue: 0.0).opacity(0.3)) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.11, green: 0.11, blue: 0.14).opacity(0.6))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
    }

    /// Text field stili — amber kenarlık
    func styledInput() -> some View {
        self
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 1.0, green: 0.75, blue: 0.0).opacity(0.4), lineWidth: 1)
                    )
            )
    }
}
