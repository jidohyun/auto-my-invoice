import SwiftUI
import UIKit

// MARK: - AppColor
//
// 웹(DaisyUI light/dark theme)과 Android(Color.kt)에서 검증된 디자인 시스템 팔레트를
// iOS(SwiftUI)에 그대로 옮긴 단일 진실 공급원(source of truth)입니다.
//
// - 에셋 카탈로그(Assets.xcassets) 없이 코드만으로 라이트/다크 적응형 색상을 제공합니다.
// - 각 색상은 hex 값에서 변환되며, UIColor { traitCollection } 클로저로 다크 모드에 대응합니다.
// - 상태 배지(draft/sent/overdue/paid/partially_paid/cancelled) 매핑은
//   웹 ui_components.ex 의 status_class 및 Android StatusColors 와 1:1로 일치합니다.
//
// 사용 예:
//   Text("결제 완료").foregroundStyle(AppColor.primary)
//   let (fg, bg) = AppColor.statusColor(for: invoice.status)
enum AppColor {

    // MARK: - Brand

    /// 브랜드 메인 컬러 (violet). light #6917E6 / dark #A855F7
    static let primary = dynamic(light: 0x6917E6, dark: 0xA855F7)

    /// primary 위에 올라가는 텍스트/아이콘 색. #F8F5FF (라이트·다크 공통)
    static let primaryContent = solid(0xF8F5FF)

    /// 보조 컬러 (blue). #3B5FE0
    static let secondary = solid(0x3B5FE0)

    /// secondary content. 어두운 배경 위 텍스트용. #F8F5FF
    static let secondaryContent = solid(0xF8F5FF)

    /// 강조 컬러 (periwinkle). #4B71CC
    static let accent = solid(0x4B71CC)

    /// accent content. #F8F5FF
    static let accentContent = solid(0xF8F5FF)

    /// 뉴트럴(짙은 남색). light #1A1D35 / dark 도 동일 톤 유지
    static let neutral = dynamic(light: 0x1A1D35, dark: 0x1A1D35)

    /// neutral content. 짙은 배경 위 텍스트. #F8F5FF
    static let neutralContent = solid(0xF8F5FF)

    // MARK: - Base (배경 / 표면 / 보더 / 텍스트)

    /// 화면 배경. base-100. light #FAFAFA / dark #151829
    static let base100 = dynamic(light: 0xFAFAFA, dark: 0x151829)

    /// 카드/표면. base-200. light #FFFFFF / dark #1E2235
    static let base200 = dynamic(light: 0xFFFFFF, dark: 0x1E2235)

    /// 보더/구분선. base-300. light #E8E9EF / dark #2C3050
    static let base300 = dynamic(light: 0xE8E9EF, dark: 0x2C3050)

    /// 기본 텍스트. base-content. light #3D4266 / dark #C8CDE3
    static let baseContent = dynamic(light: 0x3D4266, dark: 0xC8CDE3)

    // MARK: - Semantic (라이트·다크 공통)

    /// 정보(파랑). #2563EB
    static let info = solid(0x2563EB)
    static let infoContent = solid(0xFFFFFF)

    /// 성공(그린). #22C9A0
    static let success = solid(0x22C9A0)
    static let successContent = solid(0xFFFFFF)

    /// 경고(오렌지). #D97706
    static let warning = solid(0xD97706)
    static let warningContent = solid(0xFFFFFF)

    /// 에러(레드). #DC2626
    static let error = solid(0xDC2626)
    static let errorContent = solid(0xFFFFFF)
}

// MARK: - Status Badge Mapping

extension AppColor {

    /// 송장 상태 문자열을 (전경색, 배경색) 쌍으로 매핑합니다.
    ///
    /// 웹 `ui_components.ex` 의 `status_class` 및 Android `StatusColors` 와 동일한 규칙:
    /// - draft          → 회색(base-content)        / 배경 10%
    /// - sent           → info(파랑)                / 배경 10%
    /// - overdue        → error(레드)               / 배경 10%
    /// - paid           → success(그린)             / 배경 10%
    /// - partially_paid → warning(오렌지)           / 배경 10%
    /// - cancelled      → neutral 톤(회색 40%)      / 배경 10%
    /// - 그 외          → draft 와 동일하게 폴백
    ///
    /// 배경은 전경색을 10% 불투명도로 깐 변형입니다(웹의 `@10%` 규칙).
    static func statusColor(for status: String) -> (fg: Color, bg: Color) {
        switch status.lowercased() {
        case "draft":
            // 회색: base-content. 전경 60% / 배경 10%
            let fg = baseContent.opacity(0.6)
            return (fg, baseContent.opacity(0.1))

        case "sent":
            return (info, info.opacity(0.1))

        case "overdue":
            return (error, error.opacity(0.1))

        case "paid":
            return (success, success.opacity(0.1))

        case "partially_paid":
            return (warning, warning.opacity(0.1))

        case "cancelled":
            // neutral 회색: base-content 40% / 배경 10%
            let fg = baseContent.opacity(0.4)
            return (fg, baseContent.opacity(0.1))

        default:
            // 알 수 없는 상태는 draft 와 동일하게 처리
            let fg = baseContent.opacity(0.6)
            return (fg, baseContent.opacity(0.1))
        }
    }
}

// MARK: - Hex / Dynamic Helpers

private extension AppColor {

    /// 라이트·다크에서 동일한 단색을 만듭니다.
    static func solid(_ hex: UInt32) -> Color {
        Color(rgb: hex)
    }

    /// 라이트/다크 트레잇에 따라 달라지는 적응형 색을 만듭니다.
    /// 에셋 카탈로그 없이 UIColor 의 dynamic provider 로 구현합니다.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(rgb: dark)
            default:
                return UIColor(rgb: light)
            }
        })
    }
}

// MARK: - Color(rgb:) / UIColor(rgb:)

private extension Color {

    /// 0xRRGGBB 형태의 24비트 hex 값으로 sRGB Color 를 만듭니다.
    init(rgb: UInt32) {
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

private extension UIColor {

    /// 0xRRGGBB 형태의 24비트 hex 값으로 sRGB UIColor 를 만듭니다.
    convenience init(rgb: UInt32) {
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
