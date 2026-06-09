package com.invoiceflow.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = Primary,
    onPrimary = PrimaryContent,
    primaryContainer = Color(0xFFDCEBFB),
    onPrimaryContainer = Color(0xFF00386E),
    secondary = Secondary,
    onSecondary = SecondaryContent,
    secondaryContainer = Color(0xFFDCEBFB),
    onSecondaryContainer = Color(0xFF00386E),
    tertiary = Accent,
    onTertiary = AccentContent,
    background = Base100,
    onBackground = BaseContent,
    surface = Base200,
    onSurface = BaseContent,
    surfaceVariant = Base300,
    onSurfaceVariant = BaseContent,
    // M3 surfaceContainer* 역할을 중립 회색으로 고정. 명시하지 않으면 Material3가
    // primary(블루) 기반으로 톤을 자동 합성해 카드에 블루 틴트가 낀다. Apple은 순수 중립.
    surfaceContainerLowest = Color(0xFFFFFFFF),
    surfaceContainerLow = Color(0xFFFAFAFC),
    surfaceContainer = Color(0xFFF5F5F7),
    surfaceContainerHigh = Color(0xFFF0F0F2),
    surfaceContainerHighest = Color(0xFFEBEBED),
    surfaceTint = Color(0xFFFFFFFF), // elevation 틴트 비활성(흰색) — 카드 블루 오버레이 제거
    outline = Base300,
    outlineVariant = Color(0xFFE8E8EA),
    error = AppError,
    onError = AppErrorContent,
    inverseSurface = Neutral,
    inverseOnSurface = NeutralContent,
)

private val DarkColorScheme = darkColorScheme(
    primary = PrimaryDark,
    onPrimary = PrimaryContentDark,
    primaryContainer = Color(0xFF003E73),
    onPrimaryContainer = Color(0xFFDCEBFB),
    secondary = SecondaryDark,
    onSecondary = SecondaryContentDark,
    secondaryContainer = Color(0xFF003E73),
    onSecondaryContainer = Color(0xFFDCEBFB),
    tertiary = AccentDark,
    onTertiary = AccentContentDark,
    background = Base100Dark,
    onBackground = BaseContentDark,
    surface = Base200Dark,
    onSurface = BaseContentDark,
    surfaceVariant = Base300Dark,
    onSurfaceVariant = BaseContentDark,
    // 다크 타일 단계(Apple tile1/2/3). 중립 고정으로 블루 틴트 제거.
    surfaceContainerLowest = Color(0xFF1D1D1F),
    surfaceContainerLow = Color(0xFF252527),
    surfaceContainer = Color(0xFF2A2A2C),
    surfaceContainerHigh = Color(0xFF323234),
    surfaceContainerHighest = Color(0xFF3A3A3C),
    surfaceTint = Color(0xFF2A2A2C), // elevation 틴트를 중립으로
    outline = Base300Dark,
    outlineVariant = Color(0xFF3A3A3C),
    error = AppError,
    onError = AppErrorContent,
    inverseSurface = NeutralDark,
    inverseOnSurface = NeutralContentDark,
)

@Composable
fun InvoiceFlowTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme,
        typography = Typography,
        shapes = InvoiceFlowShapes,
        content = content,
    )
}
