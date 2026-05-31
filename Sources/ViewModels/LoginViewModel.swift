import Foundation
import Combine

/// Giriş ekranının iş mantığını ve durumlarını yöneten ViewModel sınıfı.
/// MVVM yapısına uygun olarak SwiftUI View katmanına veri bağlama (Data Binding) sağlar.
public final class LoginViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Kullanıcının girdiği e-posta adresi
    @Published public var email = ""
    
    /// Kullanıcının girdiği şifre
    @Published public var password = ""
    
    /// Kimlik doğrulama işleminin devam edip etmediğini belirtir (Spinner kontrolü için)
    @Published public var isLoading = false
    
    /// Kullanıcıya gösterilecek Türkçe hata mesajı (Hata yoksa nil'dir)
    @Published public var errorMessage: String? = nil
    
    /// Kullanıcının başarıyla giriş yapıp yapmadığını belirtir
    @Published public var isAuthenticated = false
    
    /// Başarıyla giriş yapmış olan aktif kullanıcı bilgisi
    @Published public var currentUser: User? = nil
    
    // MARK: - Private Dependencies
    
    /// Kimlik doğrulama işlemlerini yürüten servis (Dependency Injection)
    private let authService: AuthServiceProtocol
    
    // MARK: - Initializer
    
    /// LoginViewModel başlatıcısı.
    /// - Parameter authService: Kullanılacak kimlik doğrulama servisi (Varsayılan olarak simülasyon modunda Firebase)
    public init(authService: AuthServiceProtocol = FirebaseAuthService(isSimulationMode: true)) {
        self.authService = authService
    }
    
    // MARK: - Public Methods
    
    /// Kullanıcının girdiği bilgilerle giriş yapma sürecini başlatır.
    public func login() {
        // Hata durumunu sıfırla
        self.errorMessage = nil
        
        // 1. Alanların boş olup olmadığının kontrolü
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            self.errorMessage = AuthError.emptyFields.errorDescription
            return
        }
        
        // 2. E-posta format kontrolü
        guard isValidEmail(email) else {
            self.errorMessage = AuthError.invalidEmail.errorDescription
            return
        }
        
        // 3. Şifre uzunluk kontrolü
        guard password.count >= 6 else {
            self.errorMessage = AuthError.invalidPasswordLength.errorDescription
            return
        }
        
        // Yükleniyor durumunu aktif et
        self.isLoading = true
        
        // Servis üzerinden giriş işlemini başlat
        authService.login(email: email, password: password) { [weak self] result in
            guard let self = self else { return }
            
            // UI güncellemeleri ana iş parçacığında yapılmalıdır
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let user):
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.errorMessage = nil
                case .failure(let error):
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.errorMessage = error.errorDescription
                }
            }
        }
    }
    
    /// Oturumu kapatır ve durumları sıfırlar.
    public func logout() {
        self.email = ""
        self.password = ""
        self.currentUser = nil
        self.isAuthenticated = false
        self.errorMessage = nil
    }
    
    // MARK: - Private Helper Methods
    
    /// E-postanın geçerli bir formatta olup olmadığını doğrulayan yardımcı fonksiyon.
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
