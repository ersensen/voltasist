import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Firebase ile kimlik doğrulama işlemlerini gerçekleştiren servis sınıfı.
/// Hem gerçek Firebase Auth entegrasyonunu destekler hem de test/offline durumlar için simülasyon moduna sahiptir.
public final class FirebaseAuthService: AuthServiceProtocol {
    
    /// Testler ve çevrimdışı önizlemeler için simülasyon modunun aktif olup olmadığını belirtir.
    private let isSimulationMode: Bool
    
    /// FirebaseAuthService başlatıcısı.
    /// - Parameter isSimulationMode: True verilirse gerçek Firebase yerine simülasyon mantığı çalışır.
    public init(isSimulationMode: Bool = true) {
        self.isSimulationMode = isSimulationMode
    }
    
    /// E-posta ve şifre ile Firebase üzerinden kullanıcı doğrulaması yapar.
    public func login(email: String, password: String, completion: @escaping (Result<User, AuthError>) -> Void) {
        // Girdi kontrolleri
        guard !email.isEmpty, !password.isEmpty else {
            completion(.failure(.emptyFields))
            return
        }
        
        // E-posta format kontrolü (basit regex)
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        guard emailPred.evaluate(with: email) else {
            completion(.failure(.invalidEmail))
            return
        }
        
        // Şifre uzunluk kontrolü
        guard password.count >= 6 else {
            completion(.failure(.invalidPasswordLength))
            return
        }
        
        if isSimulationMode {
            // Çevrimdışı ve testler için simülasyon akışı (0.8 saniye gecikme ile gerçekçi ağ hissi)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) {
                // Test senaryoları doğrulaması
                if email == "test@example.com" && password == "123456" {
                    let mockUser = User(id: "mock_firebase_uid_12345", email: email, displayName: "Antigravity Test")
                    DispatchQueue.main.async {
                        completion(.success(mockUser))
                    }
                } else if email == "test@example.com" {
                    DispatchQueue.main.async {
                        completion(.failure(.wrongPassword))
                    }
                } else if email == "hata@example.com" {
                    DispatchQueue.main.async {
                        completion(.failure(.networkError))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.userNotFound))
                    }
                }
            }
        } else {
            #if canImport(FirebaseAuth)
            // Gerçek Firebase Auth entegrasyonu
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error as NSError? {
                    let parsedError = self.parseFirebaseError(error)
                    completion(.failure(parsedError))
                    return
                }
                
                if let firebaseUser = authResult?.user {
                    let user = User(
                        id: firebaseUser.uid,
                        email: firebaseUser.email ?? email,
                        displayName: firebaseUser.displayName
                    )
                    completion(.success(user))
                } else {
                    completion(.failure(.unknown("Kullanıcı bilgisi alınamadı.")))
                }
            }
            #else
            // Firebase kütüphanesi yüklü değilse simülasyon moduna geri dön veya hata ver
            completion(.failure(.unknown("Firebase SDK projenize dahil edilmemiş durumda. Lütfen simülasyon modunu kullanın veya Firebase ekleyin.")))
            #endif
        }
    }
    
    #if canImport(FirebaseAuth)
    /// Firebase'den gelen hata kodlarını anlamlı Türkçe hata mesajlarına dönüştürür.
    private func parseFirebaseError(_ error: NSError) -> AuthError {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return .unknown(error.localizedDescription)
        }
        
        switch errorCode {
        case .invalidEmail:
            return .invalidEmail
        case .wrongPassword:
            return .wrongPassword
        case .userNotFound:
            return .userNotFound
        case .networkError:
            return .networkError
        case .userDisabled:
            return .unknown("Bu kullanıcı hesabı askıya alınmıştır.")
        case .tooManyRequests:
            return .unknown("Çok fazla başarısız deneme yapıldı. Lütfen daha sonra tekrar deneyin.")
        default:
            return .unknown(error.localizedDescription)
        }
    }
    #endif
}
