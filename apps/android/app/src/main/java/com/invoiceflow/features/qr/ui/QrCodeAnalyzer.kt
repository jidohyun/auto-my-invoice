package com.invoiceflow.features.qr.ui

import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage

/**
 * AMI-42/72: CameraX [ImageAnalysis.Analyzer] that feeds frames to ML Kit's
 * barcode scanner and reports the first decoded QR value.
 *
 * The image proxy MUST be closed exactly once per frame, otherwise the
 * analysis pipeline stalls — we close it in the listeners below.
 */
class QrCodeAnalyzer(
    private val onQrCodeScanned: (String) -> Unit,
) : ImageAnalysis.Analyzer {

    private val scanner = BarcodeScanning.getClient()

    @OptIn(ExperimentalGetImage::class)
    override fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        val image = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees,
        )

        scanner.process(image)
            .addOnSuccessListener { barcodes ->
                barcodes
                    .firstOrNull { it.valueType == Barcode.TYPE_URL || it.valueType == Barcode.TYPE_TEXT }
                    ?.rawValue
                    ?.let(onQrCodeScanned)
            }
            .addOnCompleteListener { imageProxy.close() }
    }
}
