import SwiftUI
import PhotosUI

/// AMI-46 (iOS): OCR upload entry point. The user picks an invoice photo with
/// `PhotosPicker`, the image is uploaded and processed server-side, and on
/// success we hand the extracted fields to a prefilled invoice-create form.
/// Presented as a sheet from the dashboard.
struct UploadView: View {
    @State private var vm = UploadViewModel()
    @State private var selection: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var loadError: String?
    @State private var showCreate = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview

                switch vm.phase {
                case .idle:
                    picker
                case .uploading:
                    statusView("업로드 중...", system: "arrow.up.circle")
                case .processing:
                    statusView("OCR 처리 중...", system: "doc.text.magnifyingglass")
                case .completed:
                    statusView("추출 완료", system: "checkmark.circle", tint: AppColor.success)
                case .failed(let message):
                    ErrorStateView(message: message) { retry() }
                    picker
                }

                if let loadError {
                    Text(loadError).font(.footnote).foregroundStyle(AppColor.error)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("송장 스캔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onChange(of: selection) { _, newValue in
                guard let newValue else { return }
                Task { await handlePick(newValue) }
            }
            .onChange(of: vm.phase) { _, newValue in
                if case .completed = newValue { showCreate = true }
            }
            .sheet(isPresented: $showCreate, onDismiss: { dismiss() }) {
                if let extracted = vm.extracted {
                    InvoiceCreateView(prefill: extracted)
                }
            }
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColor.base200)
            if let previewImage {
                previewImage
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: AppRadius.card))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle).foregroundStyle(AppColor.baseContent.opacity(0.2))
                    Text("송장 사진을 선택하세요")
                        .font(.subheadline).foregroundStyle(AppColor.baseContent.opacity(0.5))
                }
            }
            if vm.isBusy {
                ProgressView().controlSize(.large)
            }
        }
        .frame(height: 260)
    }

    private var picker: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            Label("사진 선택", systemImage: "photo")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColor.primary)
        .disabled(vm.isBusy)
    }

    private func statusView(_ title: String, system: String, tint: Color = AppColor.primary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: system).foregroundStyle(tint)
            Text(title).font(.body)
            if vm.isBusy { ProgressView().padding(.leading, 4) }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(tint.opacity(0.1), in: .rect(cornerRadius: AppRadius.card))
    }

    private func handlePick(_ item: PhotosPickerItem) async {
        loadError = nil
        vm.reset()
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                loadError = "이미지를 불러오지 못했습니다."
                return
            }
            if let uiImage = UIImage(data: data) {
                previewImage = Image(uiImage: uiImage)
            }
            let (filename, contentType) = Self.fileInfo(for: item)
            await vm.start(imageData: data, filename: filename, contentType: contentType)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func retry() {
        previewImage = nil
        selection = nil
        vm.reset()
    }

    /// Derives a filename + MIME type from the picked item. Defaults to JPEG,
    /// which the backend's `Plug.Upload` accepts for OCR.
    private static func fileInfo(for item: PhotosPickerItem) -> (String, String) {
        if let type = item.supportedContentTypes.first {
            if type.conforms(to: .png) { return ("invoice.png", "image/png") }
            if type.conforms(to: .heic) { return ("invoice.heic", "image/heic") }
        }
        return ("invoice.jpg", "image/jpeg")
    }
}
