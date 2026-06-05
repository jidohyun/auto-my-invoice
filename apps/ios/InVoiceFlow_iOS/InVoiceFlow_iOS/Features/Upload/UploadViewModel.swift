import Foundation
import Observation

/// AMI-46 (iOS): drives the OCR upload flow. Uploads a picked image via the
/// multipart `POST /upload`, then polls `GET /extraction/:id` until the job
/// reaches a terminal state. On `completed` it exposes the extracted data so
/// the view can hand off to a prefilled invoice-create form; on `failed` it
/// surfaces the server's error message with a retry affordance.
@MainActor
@Observable
final class UploadViewModel {
    enum Phase: Equatable {
        case idle
        case uploading
        case processing
        case completed(ExtractedDataDTO)
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    private let api: APIClient
    /// Bounds the poll loop so a stuck job can't spin forever (~60s at 2s).
    private let maxPolls = 30
    private let pollInterval: UInt64 = 2_000_000_000

    init(api: APIClient = .shared) {
        self.api = api
    }

    var isBusy: Bool {
        switch phase {
        case .uploading, .processing: return true
        default: return false
        }
    }

    var extracted: ExtractedDataDTO? {
        if case .completed(let data) = phase { return data }
        return nil
    }

    /// Uploads the image, then polls the extraction job to completion.
    func start(imageData: Data, filename: String, contentType: String) async {
        phase = .uploading
        do {
            let job = try await api.uploadImage(
                data: imageData,
                filename: filename,
                contentType: contentType
            )
            await poll(jobId: job.id, current: job)
        } catch let e as APIError {
            phase = .failed(e.errorDescription ?? "업로드에 실패했습니다.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        phase = .idle
    }

    private func poll(jobId: String, current: ExtractionJobDTO) async {
        phase = .processing
        var job = current
        var attempts = 0

        while !job.isTerminal && attempts < maxPolls {
            try? await Task.sleep(nanoseconds: pollInterval)
            if Task.isCancelled { return }
            do {
                job = try await api.extractionJob(id: jobId)
            } catch let e as APIError {
                phase = .failed(e.errorDescription ?? "처리 상태를 가져오지 못했습니다.")
                return
            } catch {
                phase = .failed(error.localizedDescription)
                return
            }
            attempts += 1
        }

        applyTerminal(job)
    }

    private func applyTerminal(_ job: ExtractionJobDTO) {
        switch job.status.lowercased() {
        case "completed":
            if let data = job.extractedData {
                phase = .completed(data)
            } else {
                phase = .failed("추출 결과가 비어 있습니다.")
            }
        case "failed":
            phase = .failed(job.errorMessage ?? "OCR 처리에 실패했습니다.")
        default:
            // Hit the poll ceiling without terminating.
            phase = .failed("처리 시간이 초과되었습니다. 다시 시도해 주세요.")
        }
    }
}
