// QuotePreviewView.swift
// VoltAsist
//
// Teklif önizleme, PDF oluşturma ve WhatsApp/e-posta paylaşım ekranı.
// Teklif durumunu onaylama/reddetme akışı da bu ekrandan yönetilir.

import SwiftUI

// MARK: - QuotePreviewView

/// Teklifin son halini kullanıcıya sunan ve paylaşım aksiyonları sağlayan ekran.
struct QuotePreviewView: View {

    @ObservedObject var vm: QuoteViewModel
    @EnvironmentObject private var persistence: PersistenceService
    @Environment(\.dismiss) private var dismiss

    @State private var isGeneratingPDF = false
    @State private var showShareSheet  = false
    @State private var pdfURL: URL?
    @State private var showStatusPicker = false

    private let amber  = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let darkBG = Color(red: 0.07, green: 0.07, blue: 0.09)

    var body: some View {
        NavigationStack {
            ZStack {
                darkBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Üst bilgi kartı
                        headerCard
                        // Müşteri bilgileri
                        customerCard
                        // Kalem tablosu
                        itemsTableCard
                        // Toplam bloğu
                        totalsCard
                        // Notlar
                        if let notes = vm.currentQuote.notes, !notes.isEmpty {
                            notesCard(notes: notes)
                        }
                        // Standart uyumluluk notu
                        complianceNote
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // Yapışkan alt buton barı
                VStack {
                    Spacer()
                    shareBar
                }
            }
            .navigationTitle("Teklif Önizleme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showStatusPicker = true }) {
                        QuoteStatusBadge(status: vm.currentQuote.status)
                    }
                }
            }
            .sheet(isPresented: $showStatusPicker) {
                statusPickerSheet
            }
        }
    }

    // MARK: - Header Kartı

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(amber)
                    Text(persistence.settings.companyName.isEmpty ? "VoltAsist" : persistence.settings.companyName)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                if !persistence.settings.ownerName.isEmpty {
                    Text(persistence.settings.ownerName)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                if !persistence.settings.phone.isEmpty {
                    Text(persistence.settings.phone)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(vm.currentQuote.quoteNumber)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(amber)
                Text(vm.currentQuote.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text("Geçerlilik: " + vm.currentQuote.validUntil.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundColor(vm.isExpired ? .red : .gray)
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [amber.opacity(0.12), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.25), lineWidth: 1.5))
    }

    // MARK: - Müşteri Kartı

    private var customerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Müşteri Bilgileri", systemImage: "person.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.gray)

            Divider().background(Color.white.opacity(0.08))

            infoRow(icon: "person.circle.fill", label: "Ad Soyad / Firma", value: vm.currentQuote.customerName)
            infoRow(icon: "phone.fill", label: "Telefon", value: vm.currentQuote.customerPhone)
            if !vm.currentQuote.customerAddress.isEmpty {
                infoRow(icon: "mappin.circle.fill", label: "Adres", value: vm.currentQuote.customerAddress)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Kalem Tablosu

    private var itemsTableCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Başlık satırı
            HStack {
                Text("AÇIKLAMA")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("MİKTAR")
                    .frame(width: 70, alignment: .trailing)
                Text("BİRİM FİYAT")
                    .frame(width: 80, alignment: .trailing)
                Text("TUTAR")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.gray)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))

            Divider().background(amber.opacity(0.3))

            // Kalem satırları
            ForEach(Array(vm.currentQuote.items.enumerated()), id: \.element.id) { idx, item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        if let desc = item.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        HStack(spacing: 4) {
                            Text("KDV %\(Int(item.vatRate))")
                                .font(.system(size: 10))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                                .foregroundColor(.orange)
                            Text(item.category.rawValue)
                                .font(.system(size: 10))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(item.category.color.opacity(0.1))
                                .cornerRadius(4)
                                .foregroundColor(item.category.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(formatQty(item.quantity)) \(item.unit)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 70, alignment: .trailing)

                    Text(formatTL(item.unitPrice))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .frame(width: 80, alignment: .trailing)

                    Text(formatTL(item.totalPrice))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(amber)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(idx % 2 == 0 ? Color.clear : Color.white.opacity(0.02))

                if idx < vm.currentQuote.items.count - 1 {
                    Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 14)
                }
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Toplamlar

    private var totalsCard: some View {
        VStack(spacing: 10) {
            totalRow(label: "Ara Toplam (KDV Hariç)", value: vm.subtotalFormatted)
            totalRow(label: "Toplam KDV", value: vm.vatTotalFormatted)
            Divider().background(amber.opacity(0.4))
            HStack {
                Text("GENEL TOPLAM")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(vm.grandTotalFormatted)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(amber)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(amber.opacity(0.2), lineWidth: 1.5))
    }

    private func notesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notlar", systemImage: "note.text")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
            Text(notes)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var complianceNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))
            Text("Bu teklif IEC 60364, IEC 61921 ve TS EN standartlarına uygun hesaplamalar içermektedir.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.green.opacity(0.05))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Paylaşım Barı

    private var shareBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                // PDF İndir
                Button(action: generateAndSharePDF) {
                    HStack(spacing: 6) {
                        if isGeneratingPDF {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black)).scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.fill")
                        }
                        Text("PDF")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(amber)
                    .cornerRadius(12)
                }
                .disabled(isGeneratingPDF)

                // WhatsApp
                Button(action: {
                    vm.shareWhatsApp(settings: persistence.settings)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                        Text("WhatsApp")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(red: 0.07, green: 0.61, blue: 0.21))
                    .cornerRadius(12)
                }

                // Paylaş
                Button(action: generateAndSharePDF) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Durum Seçici

    private var statusPickerSheet: some View {
        NavigationStack {
            List(QuoteStatus.allCases, id: \.self) { status in
                Button(action: {
                    vm.updateStatus(status)
                    vm.saveQuote(to: persistence)
                    showStatusPicker = false
                }) {
                    HStack {
                        QuoteStatusBadge(status: status)
                        Spacer()
                        if status == vm.currentQuote.status {
                            Image(systemName: "checkmark").foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Durumu Güncelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { showStatusPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - PDF Üretimi

    private func generateAndSharePDF() {
        isGeneratingPDF = true
        DispatchQueue.global(qos: .userInitiated).async {
            let data    = vm.generatePDF(settings: persistence.settings)
            let fileURL = PDFService.savePDFToTemp(data: data, filename: "\(vm.currentQuote.quoteNumber).pdf")
            DispatchQueue.main.async {
                isGeneratingPDF = false
                ShareService.sharePDF(data: data, filename: "\(vm.currentQuote.quoteNumber).pdf")
            }
        }
    }

    // MARK: - Yardımcılar

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(amber)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    private func totalRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private func formatTL(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencySymbol = "₺"; f.locale = Locale(identifier: "tr_TR"); f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "₺0"
    }

    private func formatQty(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.2f", v)
    }
}

extension QuoteStatus: CaseIterable {}

#Preview {
    QuotePreviewView(vm: QuoteViewModel(settings: .defaultSettings))
        .environmentObject(PersistenceService.shared)
}
