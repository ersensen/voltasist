import XCTest
@testable import UygulamaMotoru

/// LoginViewModel'in iş mantığını doğrulayan XCTest birim (unit) testleri sınıfı.
/// Boş girdi, geçersiz e-posta, başarılı giriş ve Türkçe hata mesajlarını doğrular.
public final class LoginViewModelTests: XCTestCase {
    
    private var mockAuthService: FirebaseAuthService!
    private var sut: LoginViewModel! // System Under Test
    
    /// Her test öncesi sıfırdan servis ve ViewModel bağımlılıklarını kurar.
    public override func setUp() {
        super.setUp()
        // Testleri izole etmek amacıyla simülasyon modunda çalışan FirebaseAuthService enjekte ediyoruz.
        mockAuthService = FirebaseAuthService(isSimulationMode: true)
        sut = LoginViewModel(authService: mockAuthService)
    }
    
    /// Her test sonrası nesneleri hafızadan temizler.
    public override func tearDown() {
        sut = nil
        mockAuthService = nil
        super.tearDown()
    }
    
    // MARK: - Validation Tests
    
    /// E-posta ve şifrenin boş olması durumunda doğru Türkçe hatanın verildiğini test eder.
    func test_login_withEmptyFields_shouldReturnEmptyFieldsError() {
        // Given
        sut.email = ""
        sut.password = ""
        
        // When
        sut.login()
        
        // Then
        XCTAssertFalse(sut.isLoading, "İşlem yükleniyor durumunda olmamalıdır.")
        XCTAssertFalse(sut.isAuthenticated, "Kullanıcı doğrulanmamış olmalıdır.")
        XCTAssertEqual(sut.errorMessage, AuthError.emptyFields.errorDescription, "Hata mesajı Türkçe 'boş alan' uyarısı olmalıdır.")
    }
    
    /// Geçersiz e-posta girilmesi durumunda Türkçe 'geçersiz e-posta' hatasının verildiğini test eder.
    func test_login_withInvalidEmailFormat_shouldReturnInvalidEmailError() {
        // Given
        sut.email = "gecersiz-eposta"
        sut.password = "123456"
        
        // When
        sut.login()
        
        // Then
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertEqual(sut.errorMessage, AuthError.invalidEmail.errorDescription, "Hata mesajı geçersiz e-posta uyarısı olmalıdır.")
    }
    
    /// Şifrenin 6 karakterden kısa olması durumunda Türkçe 'şifre uzunluğu' hatasının verildiğini test eder.
    func test_login_withShortPassword_shouldReturnInvalidPasswordLengthError() {
        // Given
        sut.email = "test@example.com"
        sut.password = "123" // 6 karakterden kısa
        
        // When
        sut.login()
        
        // Then
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertEqual(sut.errorMessage, AuthError.invalidPasswordLength.errorDescription, "Şifre uzunluk hatası verilmelidir.")
    }
    
    // MARK: - Simulation Flow Tests
    
    /// Doğru kimlik bilgileriyle giriş yapıldığında başarılı oturum açma akışını doğrular.
    func test_login_withCorrectCredentials_shouldSucceed() {
        // Given
        sut.email = "test@example.com"
        sut.password = "123456"
        
        let expectation = self.expectation(description: "Başarılı giriş simülasyonu tamamlanmalı.")
        
        // When
        sut.login()
        
        // Simülasyon servisindeki global DispatchQueue gecikmesini yakalamak için bekliyoruz.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.5, handler: nil)
        
        // Then
        XCTAssertTrue(sut.isAuthenticated, "Giriş işlemi başarıyla doğrulanmalıdır.")
        XCTAssertNil(sut.errorMessage, "Hata mesajı bulunmamalıdır.")
        XCTAssertNotNil(sut.currentUser, "Aktif kullanıcı atanmış olmalıdır.")
        XCTAssertEqual(sut.currentUser?.email, "test@example.com")
    }
    
    /// Yanlış şifre girildiğinde Türkçe 'hatalı şifre' uyarısının alındığını doğrular.
    func test_login_withWrongPassword_shouldReturnWrongPasswordError() {
        // Given
        sut.email = "test@example.com"
        sut.password = "wrongpass123" // Hatalı şifre
        
        let expectation = self.expectation(description: "Hatalı şifre simülasyonu tamamlanmalı.")
        
        // When
        sut.login()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.5, handler: nil)
        
        // Then
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.currentUser)
        XCTAssertEqual(sut.errorMessage, AuthError.wrongPassword.errorDescription, "Şifre hatalı uyarısı alınmalıdır.")
    }
    
    /// Sistemde kayıtlı olmayan bir e-posta girildiğinde Türkçe 'kullanıcı bulunamadı' uyarısını doğrular.
    func test_login_withNonExistentUser_shouldReturnUserNotFoundError() {
        // Given
        sut.email = "kayitsiz@example.com"
        sut.password = "abcdef"
        
        let expectation = self.expectation(description: "Kayıtsız kullanıcı simülasyonu tamamlanmalı.")
        
        // When
        sut.login()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.5, handler: nil)
        
        // Then
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertEqual(sut.errorMessage, AuthError.userNotFound.errorDescription, "Kullanıcı bulunamadı uyarısı alınmalıdır.")
    }
    
    /// Ağ hatası simüle edildiğinde Türkçe 'ağ bağlantısı' uyarısının verildiğini doğrular.
    func test_login_withNetworkError_shouldReturnNetworkError() {
        // Given
        sut.email = "hata@example.com" // Serviste ağ hatasını tetikleyecek mock e-posta
        sut.password = "password123"
        
        let expectation = self.expectation(description: "Ağ hatası simülasyonu tamamlanmalı.")
        
        // When
        sut.login()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.5, handler: nil)
        
        // Then
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertEqual(sut.errorMessage, AuthError.networkError.errorDescription, "Ağ bağlantı hatası uyarısı alınmalıdır.")
    }
    
    /// Oturumu kapatma (logout) metodunun tüm durumları doğru sıfırladığını test eder.
    func test_logout_shouldResetAllStates() {
        // Given
        sut.email = "test@example.com"
        sut.password = "123456"
        sut.isAuthenticated = true
        sut.currentUser = User(id: "1", email: "test@example.com")
        
        // When
        sut.logout()
        
        // Then
        XCTAssertEqual(sut.email, "", "E-posta sıfırlanmalıdır.")
        XCTAssertEqual(sut.password, "", "Şifre sıfırlanmalıdır.")
        XCTAssertFalse(sut.isAuthenticated, "Kullanıcı doğrulaması kaldırılmalıdır.")
        XCTAssertNil(sut.currentUser, "Aktif kullanıcı silinmelidir.")
        XCTAssertNil(sut.errorMessage, "Hata durumu sıfırlanmalıdır.")
    }
}
