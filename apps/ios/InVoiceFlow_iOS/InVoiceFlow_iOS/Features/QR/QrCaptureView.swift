import AudioToolbox
import AVFoundation
import SwiftUI

/// AMI-42 (iOS): AVFoundation camera preview that emits decoded QR strings.
///
/// Wraps `AVCaptureSession` + `AVCaptureMetadataOutput` (QR object type) in a
/// `UIViewControllerRepresentable`. The session runs on a background queue;
/// the first successful read calls `onCode` on the main actor and stops the
/// session so we don't fire repeatedly for the same code.
struct QrCaptureView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QrCaptureController {
        let controller = QrCaptureController()
        controller.onCode = onCode
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ uiViewController: QrCaptureController, context: Context) {}
}

/// UIKit controller owning the capture session and preview layer.
final class QrCaptureController: UIViewController {
    var onCode: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "qr.session.queue")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasEmitted = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasEmitted = false
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onError?("카메라를 사용할 수 없습니다.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onError?("QR 스캔을 시작할 수 없습니다.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }
}

extension QrCaptureController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasEmitted,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else {
            return
        }
        hasEmitted = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        sessionQueue.async { [weak self] in self?.session.stopRunning() }
        onCode?(value)
    }
}
