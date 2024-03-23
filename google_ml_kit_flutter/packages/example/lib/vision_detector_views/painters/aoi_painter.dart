import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import 'coordinates_translator.dart';
typedef AOICallback = void Function(List<Rect> scaledAOIs);

class AOIPainter extends CustomPainter {
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final List<Rect> aoiRects;
  final List<Color> colors;
  final AOICallback onAOIsPainted;



  AOIPainter({
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    required this.aoiRects,
    required this.colors, 
    required this.onAOIsPainted
  }) : assert(aoiRects.length == colors.length, 'La lista de AOIs y la lista de colores deben tener el mismo tamaño.');

  @override
  void paint(Canvas canvas, Size size) {
    final List<Rect> scaledAOIs = [];
    for (int i = 0; i < aoiRects.length; i++) {
      final paint = Paint()
        ..color = colors[i] 
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
        
      final double left = translateX(aoiRects[i].left, size, imageSize, rotation, cameraLensDirection);
      final double top = translateY(aoiRects[i].top, size, imageSize, rotation, cameraLensDirection);
      final double right = translateX(aoiRects[i].right, size, imageSize, rotation, cameraLensDirection);
      final double bottom = translateY(aoiRects[i].bottom, size, imageSize, rotation, cameraLensDirection);

      final Rect scaledRect = Rect.fromLTRB(left, top, right, bottom);

      canvas.drawRect(scaledRect, paint);
      onAOIsPainted(scaledAOIs);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
