import Foundation

/// Uygulama genelinde kullanılacak kullanıcı bilgilerini tutan veri modeli.
/// Swift Codable uyumluluğu sayesinde kolayca JSON formatına dönüştürülebilir.
public struct User: Codable, Identifiable, Equatable {
    /// Kullanıcının benzersiz Firebase kimliği (UID)
    public let id: String
    
    /// Kullanıcının e-posta adresi
    public let email: String
    
    /// Kullanıcının adı ve soyadı (isteğe bağlı)
    public let displayName: String?
    
    public init(id: String, email: String, displayName: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
    }
}
