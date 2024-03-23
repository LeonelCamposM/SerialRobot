import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'command_calibration_view.dart';
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
  String focusState = 'Unfocused';
  bool anyObjectFocused = false;
  Map<String, CalibrationStats> calibrationStats = <String, CalibrationStats>{};

  @override
  void dispose() {
    _canProcess = false;
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  void initState()  {
    super.initState();
    initCalibration();
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

  // Para cargar las estadísticas de calibración
  Future<Map<String, CalibrationStats>> loadCalibrationStats() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('calibrationStats');
    if (encodedData != null) {
      final Map<String, dynamic> decodedData = jsonDecode(encodedData);
      return decodedData.map((key, value) => MapEntry(key, CalibrationStats.fromJson(value)));
    }
    return {}; // O maneja este caso según sea necesario
  }

  void initCalibration() async {
    // Carga las estadísticas de calibración de forma asíncrona
    // y luego actualiza el estado de la interfaz de usuario una vez completado.
    final Map<String, CalibrationStats> loadedStats = await loadCalibrationStats();
    if (mounted) {
      setState(() {
        calibrationStats = loadedStats;
      });
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });

    if (calibrationStats.isEmpty) {

    }else{
      print('calibrationStats: ');
      print(calibrationStats['Q1']);
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
        final Rect aoiRect = Rect.fromCenter(
          center: Offset(inputImage.metadata!.size.width / 2, inputImage.metadata!.size.height / 2),
          width: inputImage.metadata!.size.width * 0.4,
          height: inputImage.metadata!.size.height * 0.4,
        );

        // Determine if any object is focused and set the AOI color
        final String objectFocus = analyzeObjectsAndDecideActions(barcodes, inputImage.metadata!, aoiRect, calibrationStats);

        // Set the color of the AOI based on whether any object is focused
        print('focus State: $objectFocus');
        Color aoiColor = Color.fromARGB(255, 241, 30, 2);
        if(objectFocus == 'Q1') {
          aoiColor = Colors.green;
        } else if(objectFocus  == 'Q2'){
          aoiColor = Color.fromARGB(255, 233, 5, 138);
        } else if(objectFocus  == 'Q3'){
          aoiColor = Color.fromARGB(255, 7, 93, 252);
        } else if(objectFocus  == 'Q4'){
          aoiColor = Color.fromARGB(255, 237, 241, 2);
        } else if(objectFocus  == 'Q5'){
          aoiColor = Color.fromARGB(255, 36, 241, 224);
        }
        widget.focusStateController.sink.add(objectFocus);

        // Prepare the custom paint for the AOI and detected barcodes
        _customPaint = CustomPaint(
          painter: AOIPainter(
            imageSize: inputImage.metadata!.size,
            rotation: inputImage.metadata!.rotation,
            cameraLensDirection: _cameraLensDirection,
            aoiRect: aoiRect,
            color: aoiColor, // Use the updated AOI color
          ),
          foregroundPainter: BarcodeDetectorPainter(
            barcodes,
            inputImage.metadata!.size,
            inputImage.metadata!.rotation,
            _cameraLensDirection,
            objectFocus
          ),
        );
      }

      // Release the busy lock and redraw the widget
      _isBusy = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  String analyzeObjectsAndDecideActions(List<Barcode> objects, InputImageMetadata metadata, Rect aoiRect, Map<String, CalibrationStats> calibrationStats) {
    String focusState = 'Q0'; // Estado inicial para objetos fuera de cualquier cuadrante

    for (final object in objects) {
      final left = object.boundingBox.left;
      final top = object.boundingBox.top;
      final right = object.boundingBox.right;
      final bottom = object.boundingBox.bottom;

      // Calcular el centro del bounding box
      final centerX = (left + right) / 2;
      final centerY = (top + bottom) / 2;

      // Suponiendo que 'Q1' tiene los datos del cuadrante enfocado
      final stats = CalibrationStats(368.24680073, 605.23034735, 137.2774162, 222.14176212);

      if (stats != null) {
        // Rangos definidos para el enfoque basado en la desviación estándar del cuadrante "Q1"
        final double minX = stats.meanX - stats.stdDevX;
        final double maxX = stats.meanX + stats.stdDevX;
        final double minY = stats.meanY - stats.stdDevY;
        final double maxY = stats.meanY + stats.stdDevY;

        // Verificar si el centro del bounding box está dentro del rango enfocado
        final bool isFocused = centerX >= minX && centerX <= maxX && centerY >= minY && centerY <= maxY;
        if (isFocused) {
          focusState = 'Q1'; // Enfocado
          break;
        } else {
          // Aquí puedes ajustar la lógica para determinar el "desenfoque" basado en tu necesidad
          // Por ejemplo, usando la posición relativa a los límites enfocados:
          if (centerX < minX) {
            focusState = 'Q2';
          } else if (centerX > maxX) {
            focusState = 'Q3';
          } else if (centerY < minY) {
            focusState = 'Q4';
          } else if (centerY > maxY) {
            focusState = 'Q5';
          }
        }
      }
    }

    // Devolver el estado del enfoque
    return focusState;
  }
}