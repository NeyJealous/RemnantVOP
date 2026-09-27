import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct ImportSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showFileImporter = false
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Конфигурация или подписка") {
                    TextEditor(text: $text)
                        .frame(minHeight: 150)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        if let clipboard = UIPasteboard.general.string {
                            text = clipboard
                        }
                    } label: {
                        Label("Вставить из буфера", systemImage: "doc.on.clipboard")
                    }

                    Button {
                        showScanner = true
                    } label: {
                        Label("Сканировать QR", systemImage: "qrcode.viewfinder")
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Импортировать файл", systemImage: "doc.badge.plus")
                    }
                }

                Section {
                    Button {
                        Task { await performImport() }
                    } label: {
                        if isImporting {
                            HStack {
                                ProgressView()
                                Text("Импорт…")
                            }
                        } else {
                            Text("Добавить")
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                }

                if let errorMessage {
                    Section("Ошибка") {
                        Text(errorMessage)
                            .foregroundStyle(RemnantTheme.danger)
                    }
                }

                Section("Поддерживается") {
                    Text("vpn:// · vless:// · hysteria2:// · hy2:// · HTTPS-подписки · AWG/WireGuard .conf")
                        .font(.footnote)
                        .foregroundStyle(RemnantTheme.muted)
                }
            }
            .navigationTitle("Добавить VPN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText, .json, .data],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    text = try String(contentsOf: url)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerSheet { value in
                    text = value
                    showScanner = false
                }
            }
        }
    }

    private func performImport() async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            try await store.importText(text)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onValue: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    QRScannerRepresentable(onValue: onValue)
                        .ignoresSafeArea()
                } else {
                    EmptyStateView(
                        title: "Сканер недоступен",
                        systemImage: "qrcode",
                        message: "Вставьте ссылку или импортируйте файл."
                    )
                }
            }
            .navigationTitle("QR-код")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onValue: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onValue: onValue)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator

        Task { @MainActor in
            try? controller.startScanning()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onValue: (String) -> Void

        init(onValue: @escaping (String) -> Void) {
            self.onValue = onValue
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            if case .barcode(let barcode) = item,
               let value = barcode.payloadStringValue {
                onValue(value)
            }
        }
    }
}
