import SwiftUI

/// Premium tasarıma sahip Kullanıcı Giriş Ekranı View bileşeni.
/// Modern cam efekti (glassmorphism), dinamik gradyan arka plan ve yumuşak mikro-animasyonlar barındırır.
public struct LoginView: View {
    
    // MARK: - ViewModel Dependency
    @StateObject private var viewModel = LoginViewModel()
    
    // MARK: - Local UI States
    @State private var isPasswordVisible = false
    @State private var shakeAttempts: CGFloat = 0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 1. Arka Plan: Koyu ve canlı mor/mavi gradyan
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.04, blue: 0.18),
                         Color(red: 0.04, green: 0.05, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Arka plandaki parlayan küreler (Subtle Glow Effects)
            glowCircles
            
            VStack(spacing: 25) {
                Spacer()
                
                // Logo ve Başlık Alanı
                VStack(spacing: 12) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .purple.opacity(0.5), radius: 15)
                    
                    Text("Giriş Yap")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Devam etmek için hesabınıza giriş yapın")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                }
                
                // Giriş Kartı (Glassmorphic Card)
                VStack(spacing: 20) {
                    // E-posta Metin Alanı
                    customTextField(
                        title: "E-posta Adresi",
                        placeholder: "ornek@email.com",
                        text: $viewModel.email,
                        icon: "envelope.fill"
                    )
                    
                    // Şifre Metin Alanı
                    customPasswordField
                    
                    // Giriş Yap Butonu
                    loginButton
                }
                .padding(30)
                .background(.ultraThinMaterial) // Cam efekti (iOS 15+)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            .linearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .modifier(ShakeEffect(animatableData: shakeAttempts)) // Hata durumunda sallanma efekti
                
                Spacer()
                
                // Alt Bilgi
                Text("Üye değil misiniz? Yeni bir hesap oluşturun")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.purple.opacity(0.8), .cyan.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .onTapGesture {
                        // Yeni hesap akışı (Geliştirilebilir)
                    }
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            
            // 2. Üst Kısım: Türkçe Hata Mesajı Banner'ı
            if let error = viewModel.errorMessage {
                VStack {
                    errorToast(message: error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.errorMessage)
                .onAppear {
                    // Hata oluştuğunda kartı salla
                    withAnimation(.default) {
                        self.shakeAttempts += 1
                    }
                }
            }
            
            // 3. Başarılı Giriş Durumu (Yarı saydam tam ekran overlay)
            if viewModel.isAuthenticated {
                successOverlayView
            }
        }
    }
    
    // MARK: - UI Components
    
    /// Arka plandaki parlayan renkli yuvarlaklar
    private var glowCircles: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .position(x: 50, y: 150)
                
                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .position(x: geo.size.width - 50, y: geo.size.height - 150)
            }
        }
    }
    
    /// Özel E-posta Giriş Alanı
    private func customTextField(title: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.cyan)
                    .frame(width: 20)
                
                TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .medium))
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(text.wrappedValue.isEmpty ? Color.white.opacity(0.08) : Color.cyan.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    /// Şifre Giriş Alanı (Görünürlük geçiş düğmeli)
    private var customPasswordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Şifre")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                Group {
                    if isPasswordVisible {
                        TextField("", text: $viewModel.password, prompt: Text("••••••").foregroundColor(.white.opacity(0.3)))
                    } else {
                        SecureField("", text: $viewModel.password, prompt: Text("••••••").foregroundColor(.white.opacity(0.3)))
                    }
                }
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .medium))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                
                Button(action: { isPasswordVisible.toggle() }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(viewModel.password.isEmpty ? Color.white.opacity(0.08) : Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    /// Giriş Butonu
    private var loginButton: some View {
        Button(action: {
            // Klavye gizle ve login tetikle
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            viewModel.login()
        }) {
            HStack {
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Giriş Yap")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.isLoading)
        .padding(.top, 10)
    }
    
    /// Türkçe Hata Bildirim Toast/Banner yapısı
    private func errorToast(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 20))
            
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: { viewModel.errorMessage = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
    
    /// Başarılı Giriş Ekranı
    private var successOverlayView: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.5), radius: 15)
                
                VStack(spacing: 8) {
                    Text("Giriş Başarılı!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Hoş geldiniz, \(viewModel.currentUser?.displayName ?? viewModel.currentUser?.email ?? "")")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Button(action: { viewModel.logout() }) {
                    Text("Çıkış Yap")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
    }
}

// MARK: - Shake Geometry Effect
/// Hatalı giriş yapıldığında giriş kartına sallanma animasyonu katan geometrik efekt.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

// MARK: - SwiftUI Preview Support
#Preview {
    LoginView()
}
