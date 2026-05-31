# VoltAsist — Elektrikçi Yönetim ve Hesaplama Uygulaması

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017%2B-black?style=for-the-badge&logo=apple&logoColor=white"/>
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=for-the-badge&logo=swift&logoColor=white"/>
  <img src="https://img.shields.io/badge/Firebase-11.x-yellow?style=for-the-badge&logo=firebase&logoColor=white"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge"/>
</p>

---

## Hakkında

**VoltAsist**, elektrik ustaları ve mühendisleri için geliştirilmiş kapsamlı bir iOS uygulamasıdır.  
Kablo kesit hesabından kompanzasyon analizine, solar sistem boyutlandırmadan PDF teklif üretimine kadar tüm iş süreçlerini tek bir uygulamada toplar.

---

## Özellikler

### ⚡ Elektrik Hesaplama Motorları
| Motor | Standart | Açıklama |
|---|---|---|
| Kablo Kesit | IEC 60364 | Akım, kesit, gerilim düşümü, sigorta |
| Yük / Güç | IEC 60364 | Talep gücü, kVA, kVAr, fatura tahmini |
| Aydınlatma | EN 12464-1 | Lüks, lümen, armatür adedi, LED tasarrufu |
| Kompanzasyon | IEC 61921 | Qc, AKP, harmonik, trafo etkisi, ROI |

### ☀️ Solar Enerji Hesaplama
- 81 Türk ili için gerçek PSH değerleri
- On-Grid / Off-Grid / Hibrit sistem boyutlandırma
- Batarya kapasitesi (AGM / Jel / LiFePO4)
- 25 yıllık üretim ve geri ödeme analizi

### 📋 Teklif & Müşteri Yönetimi
- Kategorili kalem sistemi (Malzeme / İşçilik / Ekipman / Solar)
- PDFKit ile A4 profesyonel teklif oluşturma
- WhatsApp & e-posta paylaşımı
- Müşteri profilleri ve teklif geçmişi

### 🔒 Güvenlik & Altyapı
- Firebase Authentication (Email + Google Sign-In)
- Firestore ile opsiyonel bulut senkronizasyonu
- Yerel kalıcı depolama (UserDefaults + JSON Codable)

---

## Kurulum

### Gereksinimler
- macOS 14 (Sonoma) veya üzeri
- Xcode 15.4 veya üzeri
- iOS 17.0+ hedef cihaz / simülatör

### Adımlar

```bash
# 1. Depoyu klonla
git clone https://github.com/ersen/voltasist.git
cd voltasist

# 2. Xcode'da aç
open Package.swift
```

3. Firebase Console'dan `GoogleService-Info.plist` indir → Xcode'a ekle
4. **⌘R** ile simülatörde çalıştır

---

## Mimari

```
VoltAsist/
├── Sources/
│   ├── App/            # Uygulama giriş noktası, Firebase config
│   ├── Models/         # Codable veri modelleri (10 dosya)
│   ├── Engines/        # Hesaplama motorları (6 dosya)
│   ├── Services/       # PersistenceService, PDFService, ShareService
│   ├── ViewModels/     # ObservableObject iş mantığı (8 dosya)
│   └── Views/          # SwiftUI ekranları (14 dosya)
└── Tests/              # XCTest birim testleri (6 dosya)
```

**Pattern:** MVVM + Protocol-Oriented Services  
**UI:** SwiftUI + Charts framework  
**Storage:** UserDefaults (yerel) + Firestore (bulut, opsiyonel)

---

## Hesaplama Standartları

- **IEC 60364** — Alçak gerilim tesisatı
- **IEC 61921 / EN 60831** — Güç kondansatörleri ve kompanzasyon
- **EN 12464-1** — İç mekân aydınlatma
- **TEDAŞ Tarife Yönetmeliği** — Reaktif enerji ceza hesabı
- **EPDK** — CO₂ emisyon katsayısı (0,42 kgCO₂/kWh)
- **ETKB YEGM Güneş Atlası** — 81 il PSH değerleri

---

## Testler

```bash
# Tüm testleri çalıştır
xcodebuild test \
  -scheme VoltAsist \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro"
```

**Test Kapsamı:**
- `CableEngineTests` — 6 test
- `LoadEngineTests` — 5 test
- `CompensationEngineTests` — 7 test
- `SolarEngineTests` — 6 test
- `QuoteEngineTests` — 6 test

---

## Katkı

Pull request'ler kabul edilir. Büyük değişiklikler için önce bir Issue açın.

---

## Lisans

MIT License — © 2024 VoltAsist
