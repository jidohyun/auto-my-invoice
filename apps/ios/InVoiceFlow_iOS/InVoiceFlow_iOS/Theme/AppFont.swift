import SwiftUI

// MARK: - AppFont
//
// AutoMyInvoice 디자인 시스템의 타이포그래피 헬퍼.
//
// Apple 정본 폰트 정책을 따른다:
//   - display(헤딩/KPI 숫자): SF Pro Display (iOS system-ui)
//   - body(본문 전반):        SF Pro Text   (iOS system-ui)
//
// iOS 의 system-ui 가 곧 SF Pro 이므로 별도 .ttf 번들/등록 없이 `Font.system`
// 으로 바로 렌더링된다. 한글은 시스템이 Apple SD Gothic Neo 로 자동 폴백한다.

enum AppFont {

    // MARK: 폰트 빌더
    //
    // iOS system-ui = SF Pro Display/Text. Font.system 으로 직접 렌더링하며
    // 한글은 Apple SD Gothic Neo 로 자동 폴백한다. design 은 .default(SF Pro).

    /// 디스플레이 폰트(SF Pro Display) — 지정 size/weight.
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    /// 본문 폰트(SF Pro Text) — 지정 size/weight.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    // MARK: - 시맨틱 스타일 (타입 스케일 매핑)
    //
    // Apple weight 래더(300/400/600/700)만 사용하며 500(.medium)은 쓰지 않는다.
    // 타입 스케일 기준:
    //   h1       = 24px / bold(SF Pro Display)        → displayLarge
    //   섹션 헤딩 = 20px / semibold(SF Pro Display)    → displayTitle
    //   카드 헤딩 = 17px / semibold(SF Pro Text)       → headline
    //   본문      = 15px / regular(SF Pro Text)        → bodyText
    //   subtitle = 14px base-content/60               → callout
    //   캡션      = 12px(SF Pro Text)                  → caption
    //   money    = monospaced(숫자/금액)               → money

    /// h1 — 화면 최상단 큰 제목. 24px bold, SF Pro Display.
    static var displayLarge: Font { display(24, weight: .bold) }

    /// 섹션 제목 — 20px semibold, SF Pro Display.
    static var displayTitle: Font { display(20, weight: .semibold) }

    /// 카드/그룹 헤딩 — 17px semibold, SF Pro Text.
    static var headline: Font { body(17, weight: .semibold) }

    /// 본문 — 15px regular, SF Pro Text.
    static var bodyText: Font { body(15, weight: .regular) }

    /// 서브타이틀/보조 텍스트 — subtitle 14px, SF Pro Text.
    /// (색상은 호출부에서 base-content/60 으로 지정)
    static var callout: Font { body(14, weight: .regular) }

    /// 캡션/메타 — 12px, SF Pro Text. 라벨·날짜·상태 보조 텍스트.
    static var caption: Font { body(12, weight: .regular) }

    /// 금액/숫자 — monospaced. 자릿수 정렬이 필요한 KPI/송장 금액에 사용.
    /// Apple 래더 준수로 기본 weight 는 .regular(400) — .medium(500) 금지.
    static func money(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    /// 기본 money 스타일(17px regular 모노스페이스).
    static var moneyDefault: Font { money() }
}

// MARK: - 시맨틱 스타일 토큰 (점-단축 표기용)
//
// `.appFont(.displayLarge)` 처럼 점-단축으로 쓸 수 있도록 시맨틱 스타일을
// AppStyle 케이스로 노출한다. 시스템 Font 의 .headline/.callout/.caption 과
// 이름이 겹쳐도 AppStyle 네임스페이스 안이라 충돌하지 않는다.

enum AppFontStyle {
    case displayLarge
    case displayTitle
    case headline
    case bodyText
    case callout
    case caption

    var font: Font {
        switch self {
        case .displayLarge: return AppFont.displayLarge
        case .displayTitle: return AppFont.displayTitle
        case .headline:     return AppFont.headline
        case .bodyText:     return AppFont.bodyText
        case .callout:      return AppFont.callout
        case .caption:      return AppFont.caption
        }
    }
}

// MARK: - View 편의 모디파이어
//
// `.appFont(.displayLarge)` 형태로 호출부 가독성을 높인다.

extension View {
    /// AppFont 시맨틱 스타일을 적용한다.
    /// 예: `Text("한눈에 보기").appFont(.displayLarge)`
    func appFont(_ style: AppFontStyle) -> some View {
        self.font(style.font)
    }
}

// MARK: - 폰트 등록
//
// SF Pro Display/Text 는 iOS 시스템 폰트(system-ui)라 별도 .ttf 번들이나
// Info.plist UIAppFonts 등록이 필요 없다. `Font.system(...)` 으로 바로 렌더링되며,
// 한글은 시스템이 Apple SD Gothic Neo 로 자동 폴백한다.
