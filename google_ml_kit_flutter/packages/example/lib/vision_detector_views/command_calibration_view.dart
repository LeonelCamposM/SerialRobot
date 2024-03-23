import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'detector_view.dart';
import 'painters/aoi_painter.dart';
import 'painters/barcode_detector_painter.dart';

class CommandCalibrationView extends StatefulWidget {
  CommandCalibrationView({Key? key}) : super(key: key);

  @override
  State<CommandCalibrationView> createState() => _CommandCalibrationViewState();
}

class _CommandCalibrationViewState extends State<CommandCalibrationView> {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;
  String focusState = 'Unfocused';
  bool anyObjectFocused = false;
  Map<String, List<Offset>> taggedPoints = {
    'Q1': [],
    'Q2': [],
    'Q3': [],
    'Q4': [],
    'Q5': [],
  };
  
  String currentTag = 'Calibrate Load';
  bool calibrationView = false;
  final Map<int, String> _options = {
    0: 'Calibrate Load',
    1: 'Calibrate Save',
    2: 'Q1',
    3: 'Q2',
    4: 'Q3',
    5: 'Q4',
    6: 'Q5'
  };
  int _option = 0;

  @override
  void dispose() {
    _canProcess = false;
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          DetectorView(
            title: 'Command Calibration',
            customPaint: _customPaint,
            text: _text,
            onImage: _calibrateImage,
            initialCameraLensDirection: _cameraLensDirection,
            onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
          ),
          Positioned(
            top: 30,
            left: 100,
            right: 100,
            child: Row(
              children: [
                Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _buildDropdown(), 
                  ),
                ),
                Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() => DropdownButton<int>(
    value: _option,
    icon: const Icon(Icons.arrow_downward),
    elevation: 16,
    style: const TextStyle(color: Colors.blue),
    underline: Container(
      height: 2,
      color: Colors.blue,
    ),
    onChanged: (int? option) async { 
    if (option != null) {
      _option = option;
      currentTag = _options[option]!;

      if (currentTag == 'Calibrate Save') {
        print('taggedPoints calc: ');
        print(taggedPoints);
        final stats = calculateCalibrationStats(taggedPoints);
        print('stats Stored: ');
        print(stats);
        await saveCalibrationStats(stats);
        print('stored succesfully ');
      } else if (currentTag == 'Calibrate Load') {
        print('taggedPoints loaded: ');
        print(taggedPoints);
        final stats = await loadCalibrationStats();
        print('Stats: ');
        print(stats);
      }
      setState(() {});
    }
  },
    items: _options.entries.map<DropdownMenuItem<int>>((entry) {
      return DropdownMenuItem<int>(
        value: entry.key,
        child: Text(entry.value),
      );
    }).toList(),
  );

  // Para guardar las estadísticas de calibración
  Future<void> saveCalibrationStats(Map<String, CalibrationStats> stats) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(stats.map((key, value) => MapEntry(key, value.toJson())));
    await prefs.setString('calibrationStats', encodedData);
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

  Future<void> _calibrateImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final barcodes = await _barcodeScanner.processImage(inputImage);
    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      final Rect aoiRect = Rect.fromCenter(
        center: Offset(inputImage.metadata!.size.width / 2, inputImage.metadata!.size.height / 2),
        width: inputImage.metadata!.size.width * 0.4,
        height: inputImage.metadata!.size.height * 0.4,
      );

      if(currentTag != 'Calibrate Save' && currentTag != 'Calibrate Load') {
        for (final barcode in barcodes) {
          final centerX = (barcode.boundingBox.left + barcode.boundingBox.right) / 2;
          final centerY = (barcode.boundingBox.top + barcode.boundingBox.bottom) / 2;
          final Offset newPoint = Offset(centerX, centerY);

          if (!taggedPoints[currentTag]!.any((point) => point == newPoint)) {
            taggedPoints[currentTag]!.add(newPoint);
            print('currentTag: ');
            print(currentTag);
            print('currentPoint: ');
            print(newPoint);
          }
        }
      }
      
      final Color aoiColor = Color.fromARGB(255, 241, 2, 229);
      _customPaint = CustomPaint(
        painter: AOIPainter(
          imageSize: inputImage.metadata!.size,
          rotation: inputImage.metadata!.rotation,
          cameraLensDirection: _cameraLensDirection,
          aoiRect: aoiRect,
          color: aoiColor, 
        ),
        foregroundPainter: BarcodeDetectorPainter(
          barcodes,
          inputImage.metadata!.size,
          inputImage.metadata!.rotation,
          _cameraLensDirection,
          currentTag
        ),
      );
    }

    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}

double _mean(List<double> values) {
  // Verifica si la lista está vacía para evitar el error
  if (values.isEmpty) {
    return 0.0; // Retorna un valor por defecto o maneja este caso como creas conveniente
  }
  return values.reduce((a, b) => a + b) / values.length;
}

// Función auxiliar para calcular la desviación estándar de una lista de valores.
double _stdDev(List<double> values) {
  if (values.isEmpty) {
    return 0.0; // Retorna un valor por defecto o maneja este caso como creas conveniente
  }
  final double meanValue = _mean(values);
  final num sumOfSquaredDiffs = values.map((value) => pow(value - meanValue, 2)).reduce((a, b) => a + b);
  return sqrt(sumOfSquaredDiffs / (values.length - 1)); // N-1 para la desviación estándar de la muestra
}


  class CalibrationStats {
  final double meanX;
  final double meanY;
  final double stdDevX;
  final double stdDevY;

  CalibrationStats(this.meanX, this.meanY, this.stdDevX, this.stdDevY);

  // Método para convertir una instancia de CalibrationStats a un Map JSON.
  Map<String, dynamic> toJson() {
    return {
      'meanX': meanX,
      'meanY': meanY,
      'stdDevX': stdDevX,
      'stdDevY': stdDevY,
    };
  }

  // Método para crear una instancia de CalibrationStats a partir de un Map JSON.
  factory CalibrationStats.fromJson(Map<String, dynamic> json) {
    return CalibrationStats(
      json['meanX'] as double,
      json['meanY'] as double,
      json['stdDevX'] as double,
      json['stdDevY'] as double,
    );
  }

  @override
  String toString() {
    return 'CalibrationStats(meanX: $meanX, meanY: $meanY, stdDevX: $stdDevX, stdDevY: $stdDevY)';
  }
}

// Función para calcular las estadísticas de calibración para cada cuadrante.
Map<String, CalibrationStats> calculateCalibrationStats(Map<String, List<Offset>> calibrationData) {
  final Map<String, CalibrationStats> stats = {};

  calibrationData.forEach((quadrant, points) {
    final List<double> xValues = points.map((p) => p.dx).toList();
    final List<double> yValues = points.map((p) => p.dy).toList();

    final double meanX = _mean(xValues);
    final double stdDevX = _stdDev(xValues);
    final double meanY = _mean(yValues);
    final double stdDevY = _stdDev(yValues);

    stats[quadrant] = CalibrationStats(meanX, meanY, stdDevX, stdDevY);
  });

  return stats; 
}
