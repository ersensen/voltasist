// ElectricCalculatorViewModel.swift
// VoltAsist
//
// Kablo kesiti, yük analizi ve aydınlatma hesaplamalarını yöneten ViewModel.
// Her hesaplama türü için ayrı input/result çifti bulunur.
// Motorları doğrudan çağırarak sonuçları reaktif olarak yayınlar.

import Foundation
import Combine
import SwiftUI

// MARK: - ElectricCalculatorViewModel

/// Elektrik mühendisliği hesap makinelerinin (kablo, yük, aydınlatma) ViewModel'i.
/// CableEngine, LoadEngine ve LightingEngine motorlarını koordine eder.
final class ElectricCalculatorViewModel: ObservableObject {

    // MARK: - Kablo Hesaplama State

    /// Kablo kesiti hesaplama girdi değerleri (gerçekçi varsayılanlar)
    @Published var cableInput = CableCalculationInput(
        powerKW: 3.0,
        voltageV: 230,
        phaseCount: .single,
        powerFactor: 0.9,
        cableLengthM: 20.0,
        conductorMaterial: .copper,
        installationMethod: .conduit,
        ambientTemperatureC: 30,
        simultaneousDemandFactor: 1.0
    )

    /// Kablo hesaplama sonucu — nil ise henüz hesaplanmadı
    @Published var cableResult: CableCalculationResult? = nil

    /// Kablo hesaplama hata mesajı
    @Published var cableError: String? = nil

    // MARK: - Yük Analizi State

    /// Yük analizi girdi değerleri
    @Published var loadInput = LoadCalculationInput(
        supplyVoltageV: 400,
        phaseCount: .three,
        supplyFrequencyHz: 50,
        peakDemandFactor: 0.85,
        averagePowerFactor: 0.90,
        electricityTariffPerKWh: 4.5,
        monthlyOperatingHours: 720,
        co2EmissionFactor: 0.473
    )

    /// Yük listesi — kullanıcı ekler/çıkarır
    @Published var loadLoads: [LoadItem] = [
        LoadItem(name: "Aydınlatma",         powerW: 500,  quantity: 10, powerFactor: 0.95, demandFactor: 0.8),
        LoadItem(name: "Klima",              powerW: 2000, quantity: 3,  powerFactor: 0.85, demandFactor: 0.7),
        LoadItem(name: "Bilgisayar",         powerW: 300,  quantity: 8,  powerFactor: 0.90, demandFactor: 0.9)
    ]

    /// Yük analizi hesaplama sonucu
    @Published var loadResult: LoadCalculationResult? = nil

    /// Yük hesaplama hata mesajı
    @Published var loadError: String? = nil

    // MARK: - Aydınlatma Hesaplama State

    /// Aydınlatma tasarımı girdi değerleri
    @Published var lightingInput = LightingCalculationInput(
        roomLengthM: 8.0,
        roomWidthM: 6.0,
        roomHeightM: 3.0,
        workPlaneHeightM: 0.85,
        requiredLuxLevel: 500,
        roomType: .office,
        lightSource: .led,
        luminousEfficacy: 120,
        luminaireLumens: 4000,
        maintenanceFactor: 0.80,
        reflectanceCeiling: 0.70,
        reflectanceWall: 0.50,
        reflectanceFloor: 0.20
    )

    /// Aydınlatma hesaplama sonucu
    @Published var lightingResult: LightingCalculationResult? = nil

    /// Aydınlatma hesaplama hata mesajı
    @Published var lightingError: String? = nil

    // MARK: - Aktif Sekme

    /// Hangi hesap makinesinin gösterildiğini takip eder (0: Kablo, 1: Yük, 2: Aydınlatma)
    @Published var selectedCalculatorTab: Int = 0

    // MARK: - Init

    init() {}

    // MARK: - Kablo Hesaplama

    /// CableEngine'i çağırarak kablo kesit hesaplaması yapar.
    /// Sonuç başarılıysa cableResult güncellenir; hata durumunda cableError set edilir.
    func calculateCable() {
        cableError = nil
        do {
            let result = try CableEngine.calculate(input: cableInput)
            cableResult = result
        } catch let error as CalculationError {
            cableError  = error.localizedDescription
            cableResult = nil
        } catch {
            cableError  = "Beklenmeyen hesaplama hatası: \(error.localizedDescription)"
            cableResult = nil
        }
    }

    // MARK: - Yük Hesaplama

    /// LoadEngine'i çağırarak yük analizi hesaplaması yapar.
    func calculateLoad() {
        loadError = nil
        guard !loadLoads.isEmpty else {
            loadError = "Lütfen en az bir yük kalemi ekleyin."
            return
        }
        do {
            let result = try LoadEngine.calculate(input: loadInput, loads: loadLoads)
            loadResult = result
        } catch let error as CalculationError {
            loadError  = error.localizedDescription
            loadResult = nil
        } catch {
            loadError  = "Yük hesaplama hatası: \(error.localizedDescription)"
            loadResult = nil
        }
    }

    // MARK: - Aydınlatma Hesaplama

    /// LightingEngine'i çağırarak aydınlatma tasarımı hesaplaması yapar.
    func calculateLighting() {
        lightingError = nil
        do {
            let result = try LightingEngine.calculate(input: lightingInput)
            lightingResult = result
        } catch let error as CalculationError {
            lightingError  = error.localizedDescription
            lightingResult = nil
        } catch {
            lightingError  = "Aydınlatma hesaplama hatası: \(error.localizedDescription)"
            lightingResult = nil
        }
    }

    // MARK: - Yük Listesi Yönetimi

    /// Yük listesine yeni bir kalem ekler ve mevcut sonucu sıfırlar.
    /// - Parameter item: Eklenecek yük kalemi
    func addLoadItem(_ item: LoadItem) {
        loadLoads.append(item)
        loadResult = nil  // Önceki sonuç artık geçersiz
    }

    /// Verilen konumlardaki yük kalemlerini listeden kaldırır.
    /// - Parameter offsets: Silinecek kalem konumları (IndexSet)
    func removeLoadItem(at offsets: IndexSet) {
        loadLoads.remove(atOffsets: offsets)
        loadResult = nil
    }

    /// Yük listesindeki bir kalemi günceller.
    /// - Parameter item: Güncellenecek kalem (id eşleşmesiyle bulunur)
    func updateLoadItem(_ item: LoadItem) {
        guard let index = loadLoads.firstIndex(where: { $0.id == item.id }) else { return }
        loadLoads[index] = item
        loadResult = nil
    }

    // MARK: - Kablo Sonuç Görüntüleme Yardımcıları

    /// Kablo akımını "13,0 A" formatında döndürür
    var cableCurrentFormatted: String {
        guard let r = cableResult else { return "—" }
        return String(format: "%.1f A", r.currentA)
    }

    /// Önerilen kablo kesitini "2,5 mm²" formatında döndürür
    var cableSectionFormatted: String {
        guard let r = cableResult else { return "—" }
        return "\(r.recommendedSectionMM2) mm²"
    }

    /// Gerilim düşümü yüzdesini "2,8%" formatında döndürür
    var voltageDropFormatted: String {
        guard let r = cableResult else { return "—" }
        return String(format: "%.1f%%", r.voltageDropPercent)
    }

    /// Gerilim düşümü sınır aşımına göre uyarı rengi
    var voltageDropColor: Color {
        guard let r = cableResult else { return .primary }
        if r.voltageDropPercent > 5.0 { return .red }
        if r.voltageDropPercent > 3.0 { return .orange }
        return .green
    }

    // MARK: - Tüm Hesaplamaları Sıfırla

    /// Seçili sekmenin sonucunu ve hata mesajını temizler.
    func resetCurrentTab() {
        switch selectedCalculatorTab {
        case 0:
            cableResult = nil
            cableError  = nil
        case 1:
            loadResult  = nil
            loadError   = nil
        case 2:
            lightingResult = nil
            lightingError  = nil
        default:
            break
        }
    }
}
