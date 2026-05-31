// FirebaseConfig.swift
// VoltAsist
//
// Firebase SDK başlatma ve yapılandırma katmanı.
// AppDelegate veya @main App struct'ından çağrılır.
//
// ÖNEMLİ: GoogleService-Info.plist dosyasını Firebase Console'dan indirip
//          Xcode projesine eklemeyi unutmayın!

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firebase Başlatıcı

/// Firebase SDK'yı uygulama başlangıcında yapılandırır.
/// SwiftUI App lifecycle için AppDelegate adaptörü kullanılır.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // GoogleService-Info.plist otomatik okunur
        FirebaseApp.configure()
        return true
    }
}

// MARK: - VoltAsist App (Firebase Entegrasyonlu)

/// @main yerine bu dosyayı UygulamaMotoruApp.swift ile birleştirin:
///
/// ```swift
/// @main
/// struct UygulamaMotoruApp: App {
///     @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
///     @StateObject private var persistence = PersistenceService.shared
///
///     var body: some Scene {
///         WindowGroup {
///             MainTabView()
///                 .environmentObject(persistence)
///                 .preferredColorScheme(.dark)
///         }
///     }
/// }
/// ```

// MARK: - Firestore Servis Katmanı (Opsiyonel Bulut Sync)

/// Firestore ile teklif ve müşteri verilerini buluta senkronize eden servis.
/// PersistenceService (yerel) ile birlikte çalışır — önce yerel, arka planda bulut.
final class FirestoreService: ObservableObject {

    private let db = Firestore.firestore()
    private var userId: String? { Auth.auth().currentUser?.uid }

    // MARK: Müşteri Senkronizasyonu

    /// Müşteriyi Firestore'a yükler.
    func uploadCustomer(_ customer: Customer) async throws {
        guard let uid = userId else { return }
        let data: [String: Any] = [
            "id":          customer.id.uuidString,
            "fullName":    customer.fullName,
            "phone":       customer.phone,
            "email":       customer.email,
            "address":     customer.address,
            "companyName": customer.companyName ?? "",
            "notes":       customer.notes ?? "",
            "createdAt":   customer.createdAt,
            "isActive":    true
        ]
        try await db
            .collection("users").document(uid)
            .collection("customers").document(customer.id.uuidString)
            .setData(data, merge: true)
    }

    /// Firestore'dan müşterileri çeker.
    func fetchCustomers() async throws -> [[String: Any]] {
        guard let uid = userId else { return [] }
        let snapshot = try await db
            .collection("users").document(uid)
            .collection("customers")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.map { $0.data() }
    }

    // MARK: Teklif Senkronizasyonu

    /// Teklifi Firestore'a yükler.
    func uploadQuote(_ quote: Quote) async throws {
        guard let uid = userId else { return }
        // JSON Codable → Dictionary dönüşümü
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(quote)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        try await db
            .collection("users").document(uid)
            .collection("quotes").document(quote.id.uuidString)
            .setData(dict, merge: true)
    }

    /// Firestore'dan teklifleri çeker.
    func fetchQuotes() async throws -> [Quote] {
        guard let uid = userId else { return [] }
        let snapshot = try await db
            .collection("users").document(uid)
            .collection("quotes")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try snapshot.documents.compactMap { doc in
            let data = try JSONSerialization.data(withJSONObject: doc.data())
            return try? decoder.decode(Quote.self, from: data)
        }
    }
}
