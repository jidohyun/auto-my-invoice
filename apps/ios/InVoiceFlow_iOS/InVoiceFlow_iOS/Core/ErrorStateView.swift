import SwiftUI

/// Reusable error state with a Retry affordance. Any view that surfaces a
/// load/refresh failure should render this so the user can recover without
/// killing the app. The `retry` closure re-invokes the owning view model's
/// load method.
struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(AppColor.error)
            Text(message)
                .appFont(.bodyText)
                .foregroundStyle(AppColor.baseContent.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("다시 시도", action: retry)
                .buttonStyle(.bordered)
                .tint(AppColor.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppColor.error.opacity(0.10), in: .rect(cornerRadius: AppRadius.card))
    }
}

#Preview {
    ErrorStateView(message: "네트워크 오류: 연결할 수 없습니다.") {}
        .padding()
}
