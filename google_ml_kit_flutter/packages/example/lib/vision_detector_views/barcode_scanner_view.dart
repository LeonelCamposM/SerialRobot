import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'detector_view.dart';
import 'painters/aoi_painter.dart';
import 'painters/barcode_detector_painter.dart';

class BarcodeScannerView extends StatefulWidget {
  final StreamController<String> focusStateController;
  BarcodeScannerView({Key? key, required this.focusStateController}) : super(key: key);

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
  List<Rect> aoiRects = [];
  List<Color> aoiColors = [];
  List<Rect> scaledAOIs = [];
   bool paintAOIS = true;

  @override
  void dispose() {
    _canProcess = false;
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  void initState()  {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          DetectorView(
            title: 'Object Detector',
            customPaint: _customPaint,
            text: _text,
            onImage: _processImage,
            initialCameraLensDirection: _cameraLensDirection,
            onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
          ),
        ],
      ),
    );
  }

  List<Rect> generateGridAOIs(Size imageSize, int rows, int columns) {
    final List<Rect> aoiRects = [];
    final double sectionWidth = imageSize.width / columns;
    final double sectionHeight = imageSize.height / rows;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        aoiRects.add(Rect.fromLTWH(col * sectionWidth, row * sectionHeight, sectionWidth, sectionHeight));
      }
    }

    return aoiRects;
  }

  List<Color> generateGridColors(int count, List<Color> colors) {
    final List<Color> gridColors = [];
    for (int i = 0; i < count; i++) {
      gridColors.add(colors[i % colors.length]);
    }
    return gridColors;
  }

  String findObjectInAOIs(List<Barcode> barcodes, List<Rect> scaledAOIs) {
    for (final barcode in barcodes) {
      // Asume que el tamaño de visualización ya se ha utilizado para escalar los AOIs y el bounding box del barcode
      final Offset center = Offset(
        (barcode.boundingBox.left + barcode.boundingBox.right) / 2,
        (barcode.boundingBox.top + barcode.boundingBox.bottom) / 2,
      );

      // Comprueba si el centro del código de barras está dentro de alguno de los AOIs escalados
      for (int i = 0; i < scaledAOIs.length; i++) {
        if (scaledAOIs[i].contains(center)) {
          // Devuelve el índice del AOI que contiene el centro del código de barras
          return 'AOI $i'; 
        }
      }
    }
    // Devuelve un estado predeterminado o una cadena vacía si no se encontró el QR dentro de ningún AOI
    return 'Unfocused';
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    

    final barcodes = await _barcodeScanner.processImage(inputImage);
    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      final Size imageSize = inputImage.metadata!.size;
      if(aoiRects.isEmpty){
        final newRows = 10;
        final newColumns = 10;
        setState(() {
          aoiRects = generateGridAOIs(imageSize, newRows, newColumns);
          aoiColors = generateGridColors(newRows * newColumns, [Colors.blue]);
        });
      }

      final String objectFocus = findObjectInAOIs(barcodes, aoiRects);
      widget.focusStateController.sink.add(objectFocus);

      _customPaint = CustomPaint(
        painter: true ? AOIPainter(
          imageSize: inputImage.metadata!.size,
          rotation: inputImage.metadata!.rotation,
          cameraLensDirection: _cameraLensDirection,
          aoiRects: aoiRects,
          colors: aoiColors,
          onAOIsPainted: (List<Rect> aois) {
            scaledAOIs = aois;
          },
        ) : null, 
        foregroundPainter: BarcodeDetectorPainter(
          barcodes,
          inputImage.metadata!.size,
          inputImage.metadata!.rotation,
          _cameraLensDirection,
          objectFocus
        ),
      );

      if(paintAOIS){
        paintAOIS = false;
      }
    }

    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}
