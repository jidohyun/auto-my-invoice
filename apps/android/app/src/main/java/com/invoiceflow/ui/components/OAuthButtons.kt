package com.invoiceflow.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Code
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.invoiceflow.R

// 웹(user_login_live / user_registration_live)의 소셜 로그인 버튼을 그대로 옮긴 컴포넌트.
//   - Google: 아웃라인 버튼 + 멀티컬러 'G' 로고
//   - GitHub: 검정(#24292F) 버튼 + 코드 마크
// 현재는 UI 만 동기화된 상태로, 탭 시 onClick(준비중 안내 등)을 호출한다.

private val GitHubColor = Color(0xFF24292F)

/** Google 로그인/가입 버튼 — 아웃라인 + 컬러 'G'. */
@Composable
fun GoogleAuthButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().height(48.dp),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.5.dp, MaterialTheme.colorScheme.outline),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = MaterialTheme.colorScheme.onSurface,
        ),
    ) {
        GoogleGLogo(modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(12.dp))
        Text(text, style = MaterialTheme.typography.titleSmall)
    }
}

/** GitHub 로그인/가입 버튼 — 검정 배경 + 코드 마크. */
@Composable
fun GitHubAuthButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Button(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().height(48.dp),
        shape = RoundedCornerShape(8.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = GitHubColor,
            contentColor = Color.White,
        ),
    ) {
        Icon(Icons.Default.Code, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(12.dp))
        Text(text, style = MaterialTheme.typography.titleSmall)
    }
}

/** "또는 이메일로 계속" 구분선 — 좌우 라인 + 가운데 라벨. */
@Composable
fun OrDivider(label: String = stringResource(R.string.common_or_continue_with_email), modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        androidx.compose.material3.HorizontalDivider(
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.outline,
        )
        Text(
            label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        androidx.compose.material3.HorizontalDivider(
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.outline,
        )
    }
}

// MARK: - Google 'G' 로고 (멀티컬러, Canvas)
//
// 웹 SVG 의 4색 'G' 를 4색 호(arc) + 가운데 가로 바로 근사한다.

private val GoogleBlue = Color(0xFF4285F4)
private val GoogleGreen = Color(0xFF34A853)
private val GoogleYellow = Color(0xFFFBBC05)
private val GoogleRed = Color(0xFFEA4335)

@Composable
private fun GoogleGLogo(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val s = size.minDimension
        val lineWidth = s * 0.24f
        val inset = lineWidth / 2f
        val arcSize = Size(s - lineWidth, s - lineWidth)
        val topLeft = androidx.compose.ui.geometry.Offset(inset, inset)
        val stroke = Stroke(width = lineWidth)

        // 4색 호: 빨강(상) → 파랑(우) → 초록(하) → 노랑(좌). 0도=3시, 시계방향.
        drawArc(GoogleRed, startAngle = -90f, sweepAngle = 90f, useCenter = false, topLeft = topLeft, size = arcSize, style = stroke)
        drawArc(GoogleBlue, startAngle = 0f, sweepAngle = 90f, useCenter = false, topLeft = topLeft, size = arcSize, style = stroke)
        drawArc(GoogleGreen, startAngle = 90f, sweepAngle = 90f, useCenter = false, topLeft = topLeft, size = arcSize, style = stroke)
        drawArc(GoogleYellow, startAngle = 180f, sweepAngle = 90f, useCenter = false, topLeft = topLeft, size = arcSize, style = stroke)

        // 'G' 가로 바 (파랑) — 중심에서 오른쪽으로.
        drawRect(
            color = GoogleBlue,
            topLeft = androidx.compose.ui.geometry.Offset(s * 0.5f, s * 0.5f - lineWidth / 2f),
            size = Size(s * 0.5f - inset, lineWidth),
        )
    }
}
