import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class AOIPainter extends CustomPainter {
  final Size imageSize;
  final InputImageRotation  rotation;
  final CameraLensDirection cameraLensDirection;
  final Rect aoiRect; 
  final Color color; 

  AOIPainter({
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    required this.aoiRect,
    required this.color
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Convertir coordenadas según la orientación y el tamaño de la imagen
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    // Crear un Paint para el AOI
    final paint = Paint()
      ..color = color 
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Dibujar el rectángulo del AOI ajustado a la escala de la pantalla
    final scaledRect = Rect.fromLTRB(
      aoiRect.left * scaleX,
      aoiRect.top * scaleY,
      aoiRect.right * scaleX,
      aoiRect.bottom * scaleY,
    );

    canvas.drawRect(scaledRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
