package com.invoiceflow.ui.theme

import androidx.compose.ui.graphics.Color

// ── Light Palette ──────────────────────────────────────────────
// Apple Action Blue (single accent principle)
val Primary = Color(0xFF0066CC)
val PrimaryContent = Color(0xFFFFFFFF)

// Secondary absorbed into Primary blue family (Apple primary-focus)
val Secondary = Color(0xFF0071E3)
val SecondaryContent = Color(0xFFFFFFFF)

// Accent absorbed into Primary blue family (Apple sky link blue)
val Accent = Color(0xFF2997FF)
val AccentContent = Color(0xFFFFFFFF)

val Base100 = Color(0xFFF5F5F7)
val Base200 = Color(0xFFFFFFFF)
val Base300 = Color(0xFFE0E0E0)
val BaseContent = Color(0xFF1D1D1F)

val Neutral = Color(0xFF1D1D1F)
val NeutralContent = Color(0xFFF5F5FA)

// ── Dark Palette ────────────────────────────────────────────────
// Apple Sky Link Blue (dark accent/link)
val PrimaryDark = Color(0xFF2997FF)
val PrimaryContentDark = Color(0xFFFFFFFF)

val SecondaryDark = Color(0xFF2997FF)
val SecondaryContentDark = Color(0xFFFFFFFF)

val AccentDark = Color(0xFF2997FF)
val AccentContentDark = Color(0xFFFFFFFF)

val Base100Dark = Color(0xFF272729)
val Base200Dark = Color(0xFF2A2A2C)
val Base300Dark = Color(0xFF3A3A3C)
val BaseContentDark = Color(0xFFF5F5F7)

val NeutralDark = Color(0xFFF5F5FA)
val NeutralContentDark = Color(0xFF1D1D1F)

// ── Semantic (shared light & dark) ─────────────────────────────
val Info = Color(0xFF0071E3)
val InfoContent = Color(0xFFEFF6FF)

val Success = Color(0xFF22C9A0)
val SuccessContent = Color(0xFFECFDF5)

val Warning = Color(0xFFD97706)
val WarningContent = Color(0xFFFFFBEB)

val AppError = Color(0xFFDC2626)
val AppErrorContent = Color(0xFFFEF2F2)

// ── Status Semantic ─────────────────────────────────────────────
val StatusPaid = Success
val StatusPaidBg = Color(0x1A22C9A0)       // success/10
val StatusSent = Info
val StatusSentBg = Color(0x1A0071E3)       // info/10
val StatusOverdue = AppError
val StatusOverdueBg = Color(0x1ADC2626)    // error/10
val StatusPartiallyPaid = Warning
val StatusPartiallyPaidBg = Color(0x1AD97706) // warning/10
val StatusDraftFg = Color(0x991D1D1F)       // base-content/60
val StatusDraftBg = Color(0x1A1D1D1F)      // base-content/10
val StatusCancelledFg = Color(0x661D1D1F)  // base-content/40
val StatusCancelledBg = Color(0x1A1D1D1F)  // base-content/10
