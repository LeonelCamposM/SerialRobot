import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import 'detector_view.dart';
import 'painters/aoi_painter.dart';
import 'painters/barcode_detector_painter.dart';

class BarcodeScannerView extends StatefulWidget {
  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;

  @override
  void dispose() {
    _canProcess = false;
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetectorView(
      title: 'Barcode Scanner',
      customPaint: _customPaint,
      text: _text,
      onImage: _processImage,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final barcodes = await _barcodeScanner.processImage(inputImage);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final Rect aoiRect = Rect.fromCenter(
        center: Offset(inputImage.metadata!.size.width / 2, inputImage.metadata!.size.height / 2),
        width: inputImage.metadata!.size.width * 0.4,
        height: inputImage.metadata!.size.height * 0.4,
      );
      final aoiPainter = AOIPainter(
        imageSize: inputImage.metadata!.size,
        rotation: inputImage.metadata!.rotation,
        cameraLensDirection: _cameraLensDirection,
        aoiRect: aoiRect,
      );
      analyzeObjectsAndDecideActions(barcodes, inputImage.metadata!, aoiRect);
      final painter = BarcodeDetectorPainter(
        barcodes,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
        _customPaint = CustomPaint(
        painter: aoiPainter, // Este se dibuja primero, por debajo
        foregroundPainter: painter, // Este se dibuja encima, mostrando los objetos
      );
    } 

    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  void analyzeObjectsAndDecideActions(List<Barcode> objects, InputImageMetadata metadata, Rect aoiRect) {
    // Assuming these values were calculated from your dataset analysis in Python
    final double meanX = 368.24680073; // Combined mean for X
    final double stdX = 137.2774162;   // Combined std for X
    final double meanY = 605.23034735; // Combined mean for Y
    final double stdY = 222.14176212;  // Combined std for Y

    // Defining the range for focused based on standard deviation
    final double minX = meanX - stdX;
    final double maxX = meanX + stdX;
    final double minY = meanY - stdY;
    final double maxY = meanY + stdY;

    for (final object in objects) {
      final left = object.boundingBox.left;
      final top = object.boundingBox.top;
      final right = object.boundingBox.right;
      final bottom = object.boundingBox.bottom;

      // Calculate the center of the bounding box
      final centerX = (left + right) / 2;
      final centerY = (top + bottom) / 2;

      // Check if the center of the bounding box is within the standardized focused range
      final bool isFocused = centerX >= minX && centerX <= maxX && centerY >= minY && centerY <= maxY;

      final String focusState = isFocused ? 'Focused' : 'Unfocused';
      print('Object Bounding Box: left=$left, top=$top, right=$right, bottom=$bottom');
      print('Object Tracking value: ${object.rawValue} - Focus State: $focusState');
    }
  }
}
