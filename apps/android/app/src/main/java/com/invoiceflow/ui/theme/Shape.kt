package com.invoiceflow.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

// Design token → borderRadius mapping (Apple spec)
// field:    8dp
// selector: 8dp
// button:   8dp
// box/card: 18dp (Apple store-utility-card radius)
// full/badge: 9999px

val InvoiceFlowShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),    // field
    small = RoundedCornerShape(8.dp),          // selector / button
    medium = RoundedCornerShape(18.dp),        // box / card
    large = RoundedCornerShape(18.dp),         // card
    extraLarge = RoundedCornerShape(9999.dp),  // full / badge
)
