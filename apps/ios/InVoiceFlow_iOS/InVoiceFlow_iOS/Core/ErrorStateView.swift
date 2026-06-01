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
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("다시 시도", action: retry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 10))
    }
}

#Preview {
    ErrorStateView(message: "네트워크 오류: 연결할 수 없습니다.") {}
        .padding()
}
