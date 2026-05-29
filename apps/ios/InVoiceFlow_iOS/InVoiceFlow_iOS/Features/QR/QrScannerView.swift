import AVFoundation
import SwiftUI

/// AMI-42 (iOS): full-screen QR scanner. Hosts the AVFoundation capture view,
/// handles camera-permission state, and on a successful scan parses the pay
/// URL and reports the invoice id back to the caller (which navigates to the
/// invoice detail / pay screen).
struct QrScannerView: View {
    /// Called with the parsed invoice id once a valid pay QR is scanned.
    let onInvoice: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            Group {
                switch authorization {
                case .authorized:
                    scanner
                case .notDetermined:
                    ProgressView("카메라 권한 확인 중...")
                        .task { await requestAccess() }
                default:
                    permissionDenied
                }
            }
            .navigationTitle("QR 스캔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var scanner: some View {
        ZStack {
            QrCaptureView(
                onCode: handleCode,
                onError: { scanError = $0 }
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                if let scanError {
                    Text(scanError)
                        .font(.footnote).foregroundStyle(.white)
                        .padding(12)
                        .background(Color.red.opacity(0.9), in: .rect(cornerRadius: 8))
                } else {
                    Text("송장 결제 QR 코드를 비추세요")
                        .font(.subheadline).foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.5), in: .capsule)
                }
                Spacer().frame(height: 40)
            }
        }
    }

    private var permissionDenied: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(.secondary)
            Text("카메라 접근이 필요합니다").font(.headline)
            Text("설정 > InVoiceFlow에서 카메라 권한을 허용하세요.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private func handleCode(_ value: String) {
        guard let invoiceId = PayLinkParser.invoiceId(from: value) else {
            scanError = "유효한 결제 QR 코드가 아닙니다."
            return
        }
        onInvoice(invoiceId)
        dismiss()
    }

    private func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorization = granted ? .authorized : .denied
    }
}
