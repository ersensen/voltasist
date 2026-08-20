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

    /// Toplam gerekli kVAr için eşit büyüklükte kademelerden oluşan bir AKP kombinasyonu seçer.
    ///
    /// Önceki sürüm büyükten küçüğe açgözlü (greedy) seçim yapıyordu; bu, hedefi yukarı
    /// yuvarlamayabiliyordu (0.5 kVAr'a kadar eksik kurulum — ceza tam sıfırlanmayabiliyordu) ve
    /// tek bir dev kademe + küçük bir "kırıntı" kademe üretiyordu (örn. 125 kVAr → 100+25, aradaki
    /// 75 kVAr'lık aralıkta hiçbir ayar noktası yok). Sahada bunun iki sonucu oluyordu: (1) yük
    /// dalgalanınca sistem ya ceza sınırının altına inemiyor ya da aşırı kompanzasyona sıçrıyor,
    /// (2) en büyük kademenin kontaktörü tüm anahtarlamayı tek başına taşıyıp erken yıpranıyor.
    ///
    /// Bu sürüm hedefi eşit büyüklükte N kademeye bölüp en yakın standart değere yukarı yuvarlıyor:
    /// hem hedefi asla eksik bırakmıyor (ceil ile) hem de kademeler arası boşluğu küçültüyor hem de
    /// kontaktör aşınmasını kademeler arasında dengeliyor (gerçek AKP kontrolörlerinin eşit
    /// kademelerde yaptığı "kademe rotasyonu" ile aşınma dengelemesini mümkün kılıyor).
    /// - Parameter totalQcKVAr: Gerekli toplam kompanzasyon gücü (kVAr)
    /// - Returns: Seçilen kondansatör kademeleri (tek rating, dengeli adet)
    static func selectCapacitorSteps(totalQcKVAr: Double) -> [CapacitorStep] {
        guard totalQcKVAr > 0 else { return [] }

        // Hedef kademe sayısı — büyük ihtiyaçlarda daha fazla, ince ayarlı kademe;
        // küçük ihtiyaçlarda tek/az kademe (sabit kondansatör de olabilir) yeterli.
        let targetStepCount: Int
        switch totalQcKVAr {
        case ..<10:     targetStepCount = 1
        case 10..<25:   targetStepCount = 2
        case 25..<60:   targetStepCount = 3
        case 60..<120:  targetStepCount = 4
        case 120..<250: targetStepCount = 6
        default:        targetStepCount = 8
        }

        let idealStepSize = totalQcKVAr / Double(targetStepCount)
        let rating = standardStepRatings.first { $0 >= idealStepSize } ?? standardStepRatings.last!

        // Yukarı yuvarlama (ceil) — hedef hiçbir zaman eksik kurulmaz.
        let quantity = max(1, Int(ceil(totalQcKVAr / rating)))

        return [CapacitorStep(ratingKVAr: rating, quantity: quantity)]
    }

    // MARK: - 7.3 AKP Parametreleri

    /// Kontaktör akımı hesabı
    /// I = Qkademe / (√3 × V)
    /// - Parameters:
    ///   - stepKVAr: Kademe gücü (kVAr)
    ///   - voltageV: Sistem gerilimi (V)
    /// - Returns: Kontaktör akımı (A)
    static func calculateContactorCurrent(stepKVAr: Double, voltageV: Double) -> Double {
        let nominalCurrent = (stepKVAr * 1000.0) / (sqrt(3.0) * voltageV)
        // IEC 60831-1 / IEC 60947-4-1: kondansatör anahtarlamasında inrush akımı nedeniyle
        // kontaktör minimum 1.43× nominal kondansatör akımı kapasitesinde seçilmelidir
        return nominalCurrent * 1.43
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
        var risk: HarmonicRisk
        var reactorFactor: Double

        if thd < 5.0 {
            // Düşük harmonik — reaktör gerekmez
            risk = .low
            reactorFactor = 0.0
        } else if thd < 8.0 {
            // Orta risk — %5.67 detuned reaktör önerilir
            // Detuning: p = (50/210)² ≈ 0.0567 → rezonans frekansı 210 Hz (5. harmonik altı)
            risk = .medium
            reactorFactor = 0.0567
        } else if thd < 20.0 {
            // Yüksek harmonik — %7 detuned reaktör zorunlu
            // Detuning: p = (50/189)² ≈ 0.07 → rezonans frekansı 189 Hz (3. harmonik altı)
            risk = .high
            reactorFactor = 0.07
        } else {
            // Çok yüksek THD — %14 reaktör veya aktif filtre
            risk = .high
            reactorFactor = 0.14    // 3. harmonik koruması
        }

        // Rezonans-harmonik çakışma kontrolü — ölçülen THD düşük olsa bile Qc/trafo oranı
        // rezonansı 5. (250 Hz) veya 7. (350 Hz) harmoniğin yakınına düşürüyorsa gerçek risk
        // THD okumasından bağımsızdır: tesise sonradan bir harmonik kaynağı (VFD, kaynak
        // makinesi vb.) girdiğinde amplifikasyon/kondansatör arızası oluşur. Önceki sürümde
        // resonanceHz hesaplanıyor ama karara hiç dahil edilmiyordu — bu satırlar o eksiği kapatır.
        let dangerousHarmonicHz: [Double] = [250.0, 350.0]  // 5. ve 7. harmonik
        let resonanceNearHarmonic = dangerousHarmonicHz.contains { abs(resonanceHz - $0) / $0 < 0.15 }
        if resonanceNearHarmonic && risk == .low {
            risk = .medium
            reactorFactor = 0.0567
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

        // Bakır kayıp azalması: ΔP_cu = P_cu_nom × [(S_önce/S_nom)² − (S_sonra/S_nom)²]
        // Sonuç, nominal (anma) bakır kayıplarına oransal %; kısmi yük durumunda doğru değer verir
        let lossReduction = (pow(beforeKVA / max(1.0, transformerKVA), 2.0)
                           - pow(afterKVA  / max(1.0, transformerKVA), 2.0)) * 100.0

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

        // Aylık nakit akışı ile NBD hesabı (120 ay = 10 yıl)
        for month in 1...(10 * 12) {
            npv += monthlySavingTL / pow(1.0 + monthlyRate, Double(month))
            if month % 12 == 0 {
                cumulativeNominal += annualSaving
                cumulativeSavings.append(cumulativeNominal)
            }
        }

        // İVK (IRR) — Newton-Raphson iterasyonu (10 yıl)
        let irr = calculateIRR(investment: investmentTL, annualSaving: annualSaving, years: 10)

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
        // cos φ, S ve P'den türetilir — ceza hesabındaki Q ile aynı kaynak (tutarsızlık giderildi)
        let derivedCosPhi = min(0.9999, max(0.001, input.activePowerKW / max(0.001, input.apparentPowerKVA)))
        let requiredQc = calculateRequiredQc(
            activePowerKW: input.activePowerKW,
            currentCosPhi: derivedCosPhi,
            targetCosPhi: input.targetCosPhi
        )

        // 2b. Mevcut cos φ zaten hedefe ulaşmış — kompanzasyon gerekmiyor
        if requiredQc <= 0 {
            let currentState2 = calculateCurrentState(input: input)
            return CompensationResult(
                reactivePowerKVAr: currentState2.reactivePower,
                currentCosPhi: derivedCosPhi,
                penaltyThresholdKVAr: currentState2.penaltyThresholdKVAr,
                monthlyPenaltyTL: currentState2.monthlyPenalty,
                yearlyPenaltyTL: currentState2.monthlyPenalty * 12.0,
                requiredQcKVAr: 0.0,
                selectedSteps: [],
                totalInstalledKVAr: 0.0,
                capacitorType: "Kompanzasyon Gerekmiyor",
                stepCount: 0,
                stepSizeKVAr: 0.0,
                contactorCurrentA: 0.0,
                reactorRequired: false,
                reactorRatingPercent: 0.0,
                panelSizeDescription: "—",
                resonanceFrequencyHz: 0.0,
                harmonicRiskLevel: .low,
                recommendedReactorFactor: 0.0,
                transformerLoadBefore: nil,
                transformerLoadAfter: nil,
                capacityGainKVA: nil,
                copperLossReductionPercent: nil,
                totalMonthlySavingTL: 0.0,
                paybackMonths: 0.0,
                npvTL: 0.0,
                irrPercent: 0.0,
                cumulativeSavings: [],
                achievedCosPhi: derivedCosPhi,
                newApparentKVA: input.apparentPowerKVA
            )
        }

        // 3. Kademe seçimi
        let steps = selectCapacitorSteps(totalQcKVAr: requiredQc)
        let totalInstalledKVAr = steps.reduce(0.0) { $0 + $1.totalKVAr }

        // Aşırı kurulum kontrolü: minimum standart kademe küçük ihtiyaçlar için orantısız büyük olabilir
        let oversizeRatio = requiredQc > 0 ? (totalInstalledKVAr - requiredQc) / requiredQc : 0.0
        let oversizingWarning: String? = oversizeRatio > 0.5
            ? String(format: "Kurulan kapasite ihtiyacın %%%.0f üzerinde — minimum standart kademe (2.5 kVAr) küçük yükler için orantısız büyük kalıyor, sabit kondansatörlü özel çözüm değerlendirilebilir.", oversizeRatio * 100)
            : nil

        // Kapasitif aşırı kompanzasyon riski: kurulu kapasite, bu ölçüm noktasındaki reaktif
        // gücü aktif gücün %20'sinden fazla aşıyorsa TEDAŞ kapasitif ceza sınırına girilir
        // (bkz. MaintenanceReading.capacitivePenaltyKVArh — aynı %20 eşiği). Yük düşünce
        // (gece/hafta sonu) bu risk daha da büyür; burada sadece ölçülen noktadaki statik
        // kontrol yapılır, gerçek risk saha ölçümüyle teyit edilmelidir.
        let capacitiveExcessKVAr = max(0.0, totalInstalledKVAr - reactivePowerKVAr)
        let capacitivePenaltyThresholdKVAr = input.activePowerKW * 0.20
        let capacitiveRiskWarning: String? = capacitiveExcessKVAr > capacitivePenaltyThresholdKVAr
            ? String(format: "Kurulu kapasite (%.1f kVAr), bu ölçüm noktasındaki reaktif gücü (%.1f kVAr) aşıyor — TEDAŞ kapasitif ceza sınırı (aktif gücün %%20'si) aşılabilir. Yük düştüğünde (gece/hafta sonu) risk büyür; kademeli/otomatik kompanzasyon veya saha ölçümüyle teyit önerilir.", totalInstalledKVAr, reactivePowerKVAr)
            : nil

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
            let nominalCopperLossKW = trafoKVA * 0.015
            copperLossSavingMonthly = nominalCopperLossKW * (reduction / 100.0) * 720.0 * input.electricityTariff
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
            currentCosPhi: derivedCosPhi,
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
            newApparentKVA: newApparentKVA,
            oversizingWarning: oversizingWarning,
            capacitiveRiskWarning: capacitiveRiskWarning
        )
    }
}

