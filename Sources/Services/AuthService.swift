import Foundation

/// Firebase kimlik doğrulama hatalarını temsil eden ve Türkçe mesajlar barındıran hata tipi.
public enum AuthError: LocalizedError, Equatable {
    case emptyFields
    case invalidEmail
    case invalidPasswordLength
    case wrongPassword
    case userNotFound
    case networkError
    case unknown(String)
    
    /// Hatanın kullanıcıya gösterilecek Türkçe açıklaması
    public var errorDescription: String? {
        switch self {
        case .emptyFields:
            return "E-posta ve şifre alanları boş bırakılamaz."
        case .invalidEmail:
            return "Geçersiz bir e-posta adresi girdiniz. Lütfen e-postanızı kontrol edin."
        case .invalidPasswordLength:
            return "Şifreniz en az 6 karakter uzunluğunda olmalıdır."
        case .wrongPassword:
            return "Girdiğiniz şifre hatalı. Lütfen tekrar deneyin."
        case .userNotFound:
            return "Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı."
        case .networkError:
            return "İnternet bağlantısı hatası. Lütfen ağ bağlantınızı kontrol edip tekrar deneyin."
        case .unknown(let message):
            return "Bir hata oluştu: \(message)"
        }
    }
}

/// Kimlik doğrulama işlemlerini soyutlayan servis protokolü.
/// Protocol-oriented programming kurallarına uygun olarak tasarlanmıştır.
public protocol AuthServiceProtocol {
    /// E-posta ve şifre ile giriş yapmayı dener.
    /// - Parameters:
    ///   - email: Kullanıcının e-posta adresi
    ///   - password: Kullanıcının şifresi
    ///   - completion: Giriş işleminin sonucunu Result tipiyle döndüren callback closure
    func login(email: String, password: String, completion: @escaping (Result<User, AuthError>) -> Void)
}
