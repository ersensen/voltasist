// swift-tools-version: 5.9
// Package.swift — VoltAsist iOS Uygulaması
//
// Swift Package Manager ile Firebase ve diğer bağımlılıkları yönetir.
// Xcode → File → Add Package Dependencies yerine bu dosyayı kullanabilirsiniz.
//
// KULLANIM:
//   Xcode'da: File → Open → bu Package.swift dosyasını seçin
//   veya mevcut .xcodeproj içinde: Project → Package Dependencies → "+" → yerel paket ekle

import PackageDescription

let package = Package(
    name: "VoltAsist",
    platforms: [
        .iOS(.v17)           // iOS 17+ zorunlu (Charts, NavigationStack için)
    ],
    products: [
        .library(
            name: "VoltAsist",
            targets: ["VoltAsist"]
        )
    ],

    // ─────────────────────────────────────────────
    // BAĞIMLILIKLAR
    // ─────────────────────────────────────────────
    dependencies: [

        // 1. Firebase iOS SDK (tüm ürünler dahil)
        //    Repo: https://github.com/firebase/firebase-ios-sdk
        //    Son stabil versiyon: 11.x
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "11.0.0"
        ),

        // 2. Google Sign-In (Firebase Auth ile entegre)
        //    Repo: https://github.com/google/GoogleSignIn-iOS
        .package(
            url: "https://github.com/google/GoogleSignIn-iOS.git",
            from: "7.0.0"
        ),

    ],

    // ─────────────────────────────────────────────
    // HEDEFLER
    // ─────────────────────────────────────────────
    targets: [
        .target(
            name: "VoltAsist",
            dependencies: [
                // Firebase Auth — kullanıcı girişi ve kimlik doğrulama
                .product(name: "FirebaseAuth",      package: "firebase-ios-sdk"),

                // Firebase Firestore — bulut veri tabanı (teklif/müşteri senkronizasyonu)
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),

                // Firebase Analytics — kullanım analitikleri (opsiyonel)
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),

                // Firebase Crashlytics — hata raporlama (opsiyonel)
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),

                // Firebase Storage — PDF ve dosya yükleme (opsiyonel)
                .product(name: "FirebaseStorage",   package: "firebase-ios-sdk"),

                // Google Sign-In
                .product(name: "GoogleSignIn",      package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
            ],
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        .testTarget(
            name: "VoltAsistTests",
            dependencies: ["VoltAsist"],
            path: "Tests"
        )
    ]
)
