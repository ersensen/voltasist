// CalculationError.swift
// VoltAsist
//
// Hesaplama motorları için hata tipi.
// Engine'lerin throws varyantlarında kullanılır.

import Foundation

// MARK: - Hesaplama Hatası

/// Hesaplama motorlarının fırlatabileceği hatalar
enum CalculationError: LocalizedError {
    case invalidInput(String)
    case insufficientData(String)
    case outOfRange(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let msg):       return "Geçersiz giriş: \(msg)"
        case .insufficientData(let msg):   return "Yetersiz veri: \(msg)"
        case .outOfRange(let msg):         return "Değer aralık dışında: \(msg)"
        case .unknown(let msg):            return "Bilinmeyen hata: \(msg)"
        }
    }
}
