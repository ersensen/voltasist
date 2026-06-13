// SettingsViewModel.swift
// VoltAsist
//
// Uygulama ayarlarını görüntüleme ve kaydetme işlemlerini yöneten ViewModel.
// PersistenceService ile senkronize çalışır; fabrika ayarlarına sıfırlama destekler.

import Foundation
import Combine
import SwiftUI

// MARK: - SettingsViewModel

/// Uygulama ayarları ekranının iş mantığını yöneten ViewModel.
/// Firma adı, adres, vergi bilgileri ve teklif şablonu ayarlarını yönetir.
final class SettingsViewModel: ObservableObject {

    // MARK: - Yayınlanan Durum

    /// Düzenlenmekte olan ayarlar nesnesi
    @Published var settings: AppSettings

    /// Kaydetme işlemi tamamlandı bildirim bayrağı
    @Published var saveConfirmed: Bool = false

    /// Sıfırlama onay uyarısı göster
    @Published var showResetAlert: Bool = false

    /// Form doğrulama hata mesajı
    @Published var validationError: String? = nil

    // MARK: - Özel Değişkenler

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// PersistenceService'ten mevcut ayarları okuyarak başlatır.
    /// - Parameter persistence: Yerel veri katmanı
    init(persistence: PersistenceService) {
        self.settings = persistence.settings
        setupAutoValidation()
    }

    // MARK: - Kaydetme

    /// Mevcut ayarları doğrulayıp PersistenceService'e kaydeder.
    /// Zorunlu alanlar eksikse kaydetmeden hata mesajı gösterir.
    /// - Parameter persistence: Yerel veri katmanı
    func save(to persistence: PersistenceService) {
        guard validate() else { return }
        persistence.saveSettings(settings)
        showSaveConfirmation()
    }

    // MARK: - Fabrika Ayarlarına Sıfırla

    /// Ayarları varsayılan değerlere döndürür ve PersistenceService'e kaydeder.
    /// - Parameter persistence: Yerel veri katmanı
    func resetToDefaults(in persistence: PersistenceService) {
        settings = .defaultSettings
        persistence.saveSettings(settings)
        showResetAlert   = false
        validationError  = nil
        showSaveConfirmation()
    }

    // MARK: - Doğrulama

    /// Zorunlu alanların dolu olduğunu kontrol eder.
    /// - Returns: Tüm zorunlu alanlar doluysa true, aksi halde false
    @discardableResult
    func validate() -> Bool {
        if settings.companyName.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "Firma adı boş bırakılamaz."
            return false
        }
        if settings.phone.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "Telefon numarası boş bırakılamaz."
            return false
        }
        if settings.defaultVatRate < 0 || settings.defaultVatRate > 1.01 {
            validationError = "KDV oranı 0.0–1.0 arasında olmalıdır (0.20 = %20)."
            return false
        }
        if settings.quoteValidityDays < 1 {
            validationError = "Geçerlilik süresi en az 1 gün olmalıdır."
            return false
        }
        validationError = nil
        return true
    }

    // MARK: - Görüntüleme Yardımcıları

    /// Varsayılan KDV oranını "%20" formatında döndürür.
    var vatRateFormatted: String {
        "%\(Int((settings.defaultVatRate * 100).rounded()))"
    }

    /// Teklif geçerlilik süresini "30 gün" formatında döndürür.
    var validityDaysFormatted: String {
        "\(settings.quoteValidityDays) gün"
    }

    // MARK: - Otomatik Doğrulama Kurulumu

    /// Kullanıcı yazarken anlık validasyon yapar (isimde minimum 2 karakter)
    private func setupAutoValidation() {
        $settings
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                // Hata varken input değişince hatayı temizle
                if self?.validationError != nil {
                    _ = self?.validate()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Özel Yardımcı

    /// Kaydetme başarılıydı bildirimi — 2 saniye sonra otomatik kapanır
    private func showSaveConfirmation() {
        saveConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.saveConfirmed = false
        }
    }
}
