import Foundation

/// Çevrimdışı ve test/önizleme durumları için mock (simüle) kimlik doğrulama işlemlerini gerçekleştiren servis sınıfı.
/// Firebase bağımlılığı olmadan çalışır.
public final class FirebaseAuthService: AuthServiceProtocol {
    
    /// Testler ve çevrimdışı önizlemeler için simülasyon modunun aktif olup olmadığını belirtir (Firebase olmadığı için daima true çalışır).
    private let isSimulationMode: Bool
    
    /// FirebaseAuthService başlatıcısı.
    /// - Parameter isSimulationMode: Simülasyon modunu kontrol eder (Firebase kaldırıldığı için daima simülasyon modunda çalışır).
    public init(isSimulationMode: Bool = true) {
        self.isSimulationMode = isSimulationMode
    }
    
    /// E-posta ve şifre ile simüle edilmiş kullanıcı doğrulaması yapar.
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
    }
}
