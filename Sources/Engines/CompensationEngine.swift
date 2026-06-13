// CompensationEngine.swift
// VoltAsist
//
// Reaktif güç kompanzasyonu hesaplama motoru.
// TEDAŞ ceza, kondansatör seçimi, harmonik analizi, transformatör etkisi ve ROI.

import Foundation

// MARK: - Kompanzasyon Hesaplama Motoru

/// Reaktif güç kompanzasyonu tam analiz motoru
struct CompensationEngine {

    // MARK: Sabitler

    /// Standart kondansatör kademe değerleri (kVAr) — piyasa serileri
    static let standardStepRatings: [Double] = [
        2.5, 5.0, 7.5, 10.0, 12.5, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0, 60.0, 75.0, 100.0
    ]

    /// TEDAŞ reaktif enerji ceza sınırı — endüktif reaktif / aktif = %33 (tan φ ≈ 0.33)
    static let tedasInductiveLimitTanPhi: Double = 0.33

    /// Aylık çalışma saati (saat/ay) — TEDAŞ ceza hesabı için
    static let monthlyHours: Double = 720.0

    // MARK: - 7.1 Mevcut Durum ve TEDAŞ Ceza Hesabı

    /// Mevcut reaktif güç ve TEDAŞ ceza hesabı
    /// - Parameter input: Kompanzasyon girdi parametreleri
    /// - Returns: (reaktif güç kVAr, ceza eşiği kVAr, aylık ceza TL)
    static func calculateCurrentState(
        input: CompensationInput
    ) -> (reactivePower: Double, penaltyThresholdKVAr: Double, monthlyPenalty: Double) {

        // Reaktif güç: Q = √(S² - P²)  [kVAr]
        let reactivePower = sqrt(
            max(0.0,
                input.apparentPowerKVA * input.apparentPowerKVA
                - input.activePowerKW * input.activePowerKW
            )
        )

        // TEDAŞ ceza eşiği: Qceza = P × tan(φ_sınır) = P × 0.33  [kVAr]
        let penaltyThreshold = input.activePowerKW * tedasInductiveLimitTanPhi

        // Cezaya tabi reaktif enerji (kVArh/ay)
        let penaltyKVAr = max(0.0, reactivePower - penaltyThreshold)
        let penaltyKVArh = penaltyKVAr * monthlyHours

        // Aylık ceza (TL) = kVArh × TL/kVArh tarifesi
        let monthlyPenalty = penaltyKVArh * input.electricityTariff

        return (reactivePower, penaltyThreshold, monthlyPenalty)
    }

    // MARK: - 7.2 Gerekli Kondansatör Gücü

    /// Gerekli kompanzasyon gücü hesabı
    /// Formül: Qc = P × (tan φ₁ - tan φ₂)
    /// - Parameters:
    ///   - activePowerKW: Aktif güç (kW)
    ///   - currentCosPhi: Mevcut güç faktörü (cos φ₁)
    ///   - targetCosPhi: Hedef güç faktörü (cos φ₂)
    /// - Returns: Gerekli kondansatör gücü (kVAr)
    static func calculateRequiredQc(
        activePowerKW: Double,
        currentCosPhi: Double,
        targetCosPhi: Double
    ) -> Double {
        let tanPhi1 = tan(acos(max(0.001, min(currentCosPhi, 0.9999))))
        let tanPhi2 = tan(acos(max(0.001, min(targetCosPhi, 0.9999))))
        return activePowerKW * (tanPhi1 - tanPhi2)
    }

    // MARK: - Standart Kademe Seçimi

    /// Toplam gerekli kVAr için optimum standart kademe kombinasyonunu seç
    /// Büyük kademelerden başlayarak açgözlü algoritma kullanır
    /// - Parameter totalQcKVAr: Gerekli toplam kompanzasyon gücü (kVAr)
    /// - Returns: Seçilen kondansatör kademeleri
    static func selectCapacitorSteps(totalQcKVAr: Double) -> [CapacitorStep] {
        var remaining = totalQcKVAr
        var steps: [CapacitorStep] = []

        // Büyük kademeden küçüğe doğru seç
        let sortedRatings = standardStepRatings.sorted(by: >)

        for rating in sortedRatings {
            if remaining <= 0 { break }
            let qty = Int(remaining / rating)
            if qty > 0 {
                steps.append(CapacitorStep(ratingKVAr: rating, quantity: qty))
                remaining -= rating * Double(qty)
            }
        }

        // Kalan küçük değer için en küçük kademeyi ekle
        if remaining > 0.5 && remaining <= sortedRatings.last ?? 2.5 {
            if let smallest = standardStepRatings.first {
                steps.append(CapacitorStep(ratingKVAr: smallest, quantity: 1))
            }
        }

        return steps.filter { $0.quantity > 0 }
    }

    // MARK: - 7.3 AKP Parametreleri

    /// Kontaktör akımı hesabı
    /// I = Qkademe / (√3 × V)
    /// - Parameters:
    ///   - stepKVAr: Kademe gücü (kVAr)
    ///   - voltageV: Sistem gerilimi (V)
    /// - Returns: Kontaktör akımı (A)
    static func calculateContactorCurrent(stepKVAr: Double, voltageV: Double) -> Double {
        return (stepKVAr * 1000.0) / (sqrt(3.0) * voltageV)
    }

    /// AKP pano boyutu önerisi (kademe sayısına göre)
    private static func panelSizeDescription(stepCount: Int) -> String {
        switch stepCount {
        case 1...4:   return "400×600×200 mm (Küçük)"
        case 5...8:   return "600×800×250 mm (Orta)"
        case 9...12:  return "800×1200×300 mm (Büyük)"
        default:       return "1000×2000×400 mm (XL — Özel İmalat)"
        }
    }

    // MARK: - 7.4 Harmonik Analizi

    /// Harmonik rezonans analizi
    /// Paralel rezonans frekansı: f_r = 50 × √(S_trafo / Qc)
    /// THD > %8: reaktör zorunlu; reaktör seçimi harmonik mertebesine göre
    /// - Parameters:
    ///   - transformerKVA: Trafo gücü (kVA) — nil ise varsayılan 1000 kVA kullanılır
    ///   - installedQcKVAr: Kurulu kondansatör gücü (kVAr)
    ///   - thd: Toplam Harmonik Bozulma (THD %)
    /// - Returns: (rezonans Hz, risk seviyesi, önerilen reaktör faktörü)
    static func analyzeHarmonics(
        transformerKVA: Double?,
        installedQcKVAr: Double,
        thd: Double
    ) -> (resonanceHz: Double, risk: HarmonicRisk, reactorFactor: Double) {

        let trafoKVA = transformerKVA ?? 1000.0

        // Paralel rezonans frekansı
        // f_r = 50 × √(S_sc / Qc) — S_sc ≈ S_trafo / Zk (Zk: %6 kısa devre empedansı)
        let shortCircuitMVA = trafoKVA / 60.0  // Zk = %6 varsayımı
        let resonanceHz = 50.0 * sqrt((shortCircuitMVA * 1000.0) / max(1.0, installedQcKVAr))

        // Risk seviyesi değerlendirmesi
        let risk: HarmonicRisk
        let reactorFactor: Double

        if thd < 5.0 {
            // Düşük harmonik — reaktör gerekmez
            risk = .low
            reactorFactor = 0.0
        } else if thd < 8.0 {
            // Orta risk — %5.67 detuned reaktör önerilir (250 Hz koruma)
            risk = .medium
            reactorFactor = 0.0567  // p = (50/250)² ≈ 0.04 → pratik: 5.67%
        } else if thd < 20.0 {
            // Yüksek harmonik — %7 detuned reaktör zorunlu (350 Hz 7. harmonik)
            risk = .high
            reactorFactor = 0.07    // p = (50/210)² ≈ 0.0566 → 7% detuned
        } else {
            // Çok yüksek THD — %14 reaktör veya aktif filtre
            risk = .high
            reactorFactor = 0.14    // 3. harmonik koruması
        }

        return (resonanceHz, risk, reactorFactor)
    }

    // MARK: - 7.5 Transformatör Etkisi

    /// Kompanzasyonun transformatör yükü üzerindeki etkisi
    /// - Parameters:
    ///   - transformerKVA: Trafo anma gücü (kVA)
    ///   - beforeKVA: Kompanzasyon öncesi görünür güç (kVA)
    ///   - afterKVA: Kompanzasyon sonrası görünür güç (kVA)
    /// - Returns: (önceki yük %, sonraki yük %, kazanılan kapasite kVA, bakır kayıp azalması %)
    static func calculateTransformerImpact(
        transformerKVA: Double,
        beforeKVA: Double,
        afterKVA: Double
    ) -> (loadBefore: Double, loadAfter: Double, capacityGain: Double, copperLossReduction: Double) {

        // Yüklenme oranı (%)
        let loadBefore = (beforeKVA / transformerKVA) * 100.0
        let loadAfter  = (afterKVA  / transformerKVA) * 100.0

        // Kazanılan kapasite
        let capacityGain = max(0.0, beforeKVA - afterKVA)

        // Bakır kayıp azalması: P_cu ∝ I² ∝ S²
        // Azalma% = (1 - (S_sonra/S_önce)²) × 100
        let lossReduction = (1.0 - pow(afterKVA / max(1.0, beforeKVA), 2.0)) * 100.0

        return (loadBefore, loadAfter, capacityGain, lossReduction)
    }

    // MARK: - 7.6 ROI Hesabı

    /// Yatırım geri ödeme, NBD ve İVK hesabı
    /// - Parameters:
    ///   - investmentTL: Toplam yatırım (TL)
    ///   - monthlySavingTL: Aylık tasarruf (TL — ceza + kayıp azalması)
    ///   - discountRate: Yıllık iskonto oranı (örn: 0.15 = %15)
    /// - Returns: (geri ödeme ayı, 10 yıllık NBD TL, İVK %, yıllık kümülatif dizisi)
    static func calculateROI(
        investmentTL: Double,
        monthlySavingTL: Double,
        discountRate: Double
    ) -> (paybackMonths: Double, npv: Double, irr: Double, cumulativeSavings: [Double]) {

        // Geri ödeme süresi (ay)
        let paybackMonths = monthlySavingTL > 0 ? investmentTL / monthlySavingTL : Double.infinity

        // Yıllık tasarruf
        let annualSaving = monthlySavingTL * 12.0

        // 10 yıllık NBD
        // NBD = Σ(t=1..10) [ tasarruf_t / (1+r)^t ] - yatırım
        let monthlyRate = discountRate / 12.0
        var npv = -investmentTL
        var cumulativeSavings: [Double] = []
        var cumulativeNominal = 0.0

        for year in 1...10 {
            // Yıllık nakit akışı — basit model: sabit yıllık tasarruf
            let discountFactor = pow(1.0 + discountRate, -Double(year))
            npv += annualSaving * discountFactor
            cumulativeNominal += annualSaving
            cumulativeSavings.append(cumulativeNominal)
        }

        // İVK (IRR) — Newton-Raphson iterasyonu (10 yıl)
        let irr = calculateIRR(investment: investmentTL, annualSaving: annualSaving, years: 10)

        // Aylık iskonto oranı uyarısı — kullanılmıyor ama derleme için tutuluyor
        _ = monthlyRate

        return (paybackMonths, npv, irr, cumulativeSavings)
    }

    /// İç Verimlilik Oranı (İVK/IRR) — Newton-Raphson iterasyonu
    /// NPV(r) = -I + Σ CF/(1+r)^t = 0 çözümü
    private static func calculateIRR(investment: Double, annualSaving: Double, years: Int) -> Double {
        guard annualSaving > 0, investment > 0 else { return 0.0 }

        // Başlangıç tahmini: basit geri ödeme oranı
        var rate = annualSaving / investment

        for _ in 0..<50 {  // Maksimum 50 iterasyon
            var npvAtRate = -investment
            var dNpv = 0.0  // NPV'nin türevi

            for t in 1...years {
                let discountFactor = pow(1.0 + rate, -Double(t))
                npvAtRate += annualSaving * discountFactor
                dNpv -= Double(t) * annualSaving * pow(1.0 + rate, -Double(t + 1))
            }

            if abs(dNpv) < 1e-10 { break }
            let newRate = rate - npvAtRate / dNpv

            if abs(newRate - rate) < 1e-8 {
                rate = newRate
                break
            }
            rate = max(-0.99, min(newRate, 10.0))  // Sınırla
        }

        return rate * 100.0  // % olarak
    }

    // MARK: - Throws Varyantı (ViewModel Uyumlu)

    /// Hesaplamayı yapar; giriş geçersizse CalculationError fırlatır.
    static func calculate(input: CompensationInput) throws -> CompensationResult {
        guard input.isValid else {
            throw CalculationError.invalidInput("Kompanzasyon giriş parametreleri geçersiz.")
        }
        return _calculate(input: input)
    }

    // MARK: - Ana Hesaplama (Private)

    /// Kompanzasyon sisteminin tam analizini gerçekleştir
    /// - Parameter input: Tüm giriş parametreleri
    /// - Returns: Kapsamlı hesaplama sonuçları
    private static func _calculate(input: CompensationInput) -> CompensationResult {

        // 1. Mevcut durum
        let currentState = calculateCurrentState(input: input)
        let reactivePowerKVAr = currentState.reactivePower
        let penaltyThreshold  = currentState.penaltyThresholdKVAr
        let monthlyPenalty    = currentState.monthlyPenalty
        let yearlyPenalty     = monthlyPenalty * 12.0

        // 2. Gerekli kondansatör gücü
        let requiredQc = calculateRequiredQc(
            activePowerKW: input.activePowerKW,
            currentCosPhi: input.measuredCosPhi,
            targetCosPhi: input.targetCosPhi
        )

        // 3. Kademe seçimi
        let steps = selectCapacitorSteps(totalQcKVAr: requiredQc)
        let totalInstalledKVAr = steps.reduce(0.0) { $0 + $1.totalKVAr }

        // AKP mi, sabit mi?
        let totalStepCount = steps.reduce(0) { $0 + $1.quantity }
        let isAutomatic = totalStepCount > 1
        let capacitorTypeStr = isAutomatic ? "Otomatik (AKP)" : "Sabit Kondansatör"

        // Dominant kademe büyüklüğü
        let largestStep = steps.max(by: { $0.ratingKVAr < $1.ratingKVAr })
        let stepSizeKVAr = largestStep?.ratingKVAr ?? requiredQc

        // Kontaktör akımı
        let contactorA = calculateContactorCurrent(
            stepKVAr: stepSizeKVAr,
            voltageV: input.systemVoltageV
        )

        // 4. Harmonik analizi
        let harmonics = analyzeHarmonics(
            transformerKVA: input.transformerKVA,
            installedQcKVAr: totalInstalledKVAr,
            thd: input.totalHarmonicDistortion
        )

        let reactorRequired = harmonics.risk != .low
        let reactorRatingPercent = harmonics.reactorFactor * 100.0

        // Pano boyutu
        let panelDesc = panelSizeDescription(stepCount: totalStepCount)

        // 5. Transformatör etkisi
        var trafoLoadBefore: Double? = nil
        var trafoLoadAfter: Double?  = nil
        var capacityGain: Double?    = nil
        var copperLossReduction: Double? = nil

        if let trafoKVA = input.transformerKVA {
            let beforeKVA = input.apparentPowerKVA
            // Kompanzasyon sonrası görünür güç
            let newReactiveKVAr = max(0.0, reactivePowerKVAr - totalInstalledKVAr)
            let newApparentKVA = sqrt(
                input.activePowerKW * input.activePowerKW + newReactiveKVAr * newReactiveKVAr
            )
            let impact = calculateTransformerImpact(
                transformerKVA: trafoKVA,
                beforeKVA: beforeKVA,
                afterKVA: newApparentKVA
            )
            trafoLoadBefore = impact.loadBefore
            trafoLoadAfter  = impact.loadAfter
            capacityGain    = impact.capacityGain
            copperLossReduction = impact.copperLossReduction
        }

        // 6. Ulaşılan güç faktörü
        let newReactiveKVAr = max(0.0, reactivePowerKVAr - totalInstalledKVAr)
        let newApparentKVA = sqrt(
            input.activePowerKW * input.activePowerKW + newReactiveKVAr * newReactiveKVAr
        )
        let achievedCosPhi = newApparentKVA > 0
            ? input.activePowerKW / newApparentKVA
            : 1.0

        // 7. Ekonomik analiz
        let copperLossSavingMonthly: Double
        if let reduction = copperLossReduction, let trafoKVA = input.transformerKVA {
            let nominalCopperLossKW = trafoKVA * 0.015 / 1000.0
            copperLossSavingMonthly = nominalCopperLossKW * (reduction / 100.0) * 720.0 * 4.50
        } else {
            copperLossSavingMonthly = 0.0
        }

        let totalMonthlySaving = monthlyPenalty + copperLossSavingMonthly

        let roi = calculateROI(
            investmentTL: input.investmentCostTL,
            monthlySavingTL: totalMonthlySaving,
            discountRate: input.discountRate
        )

        return CompensationResult(
            reactivePowerKVAr: reactivePowerKVAr,
            currentCosPhi: input.measuredCosPhi,
            penaltyThresholdKVAr: penaltyThreshold,
            monthlyPenaltyTL: monthlyPenalty,
            yearlyPenaltyTL: yearlyPenalty,
            requiredQcKVAr: requiredQc,
            selectedSteps: steps,
            totalInstalledKVAr: totalInstalledKVAr,
            capacitorType: capacitorTypeStr,
            stepCount: totalStepCount,
            stepSizeKVAr: stepSizeKVAr,
            contactorCurrentA: contactorA,
            reactorRequired: reactorRequired,
            reactorRatingPercent: reactorRatingPercent,
            panelSizeDescription: panelDesc,
            resonanceFrequencyHz: harmonics.resonanceHz,
            harmonicRiskLevel: harmonics.risk,
            recommendedReactorFactor: harmonics.reactorFactor,
            transformerLoadBefore: trafoLoadBefore,
            transformerLoadAfter: trafoLoadAfter,
            capacityGainKVA: capacityGain,
            copperLossReductionPercent: copperLossReduction,
            totalMonthlySavingTL: totalMonthlySaving,
            paybackMonths: roi.paybackMonths,
            npvTL: roi.npv,
            irrPercent: roi.irr,
            cumulativeSavings: roi.cumulativeSavings,
            achievedCosPhi: achievedCosPhi,
            newApparentKVA: newApparentKVA
        )
    }
}

