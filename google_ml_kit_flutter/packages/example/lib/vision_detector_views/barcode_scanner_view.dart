import 'dart:async';
import 'dart:math';

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
  String focusState = 'Unfocused';
  bool anyObjectFocused = false;
  Map<String, List<Offset>> taggedPoints = {
    'Q1': [],
    'Q2': [],
    'Q3': [],
    'Q4': [],
    'Q5': [],
  };
  
  String currentTag = 'Calibrate'; // El tag seleccionado actualmente
  bool calibrationView = false;
  // Asegúrate de tener estas variables definidas en tu clase State
  final Map<int, String> _options = {
    0: 'Calibrate',
    1: 'Q1',
    2: 'Q2',
    3: 'Q3',
    4: 'Q4',
    5: 'Q5'
  };

int _option = 0; // Esta será la opción seleccionada, comenzando en 'Q1'
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
            title: 'Object Detector',
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
                    child: _buildDropdown(), // Usar el método _buildDropdown aquí
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
    onChanged: (int? option) {
      if (option != null) {
        setState(() {
          _option = option;
          currentTag = _options[option]!;
          if(currentTag == 'Calibrate'){
            print('current points Q1: ');
            print(taggedPoints['Q1']);
            print('current points Q2: ');
            print(taggedPoints['Q2']);
          }
        });
      }
    },
    items: _options.entries.map<DropdownMenuItem<int>>((entry) {
      return DropdownMenuItem<int>(
        value: entry.key,
        child: Text(entry.value),
      );
    }).toList(),
  );

  Future<void> _processImage(InputImage inputImage) async {
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

      // Determine if any object is focused and set the AOI color
      final String objectFocus = analyzeObjectsAndDecideActions(barcodes, inputImage.metadata!, aoiRect);

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

  String analyzeObjectsAndDecideActions(List<Barcode> objects, InputImageMetadata metadata, Rect aoiRect) {
    // Valores por defecto
    final double meanX = 368.24680073; // Media para X
    final double stdX = 137.2774162;   // Desviación estándar para X
    final double meanY = 605.23034735; // Media para Y
    final double stdY = 222.14176212;  // Desviación estándar para Y

    // Rango definido para el enfoque basado en la desviación estándar
    final double minX = meanX - stdX;
    final double maxX = meanX + stdX;
    final double minY = meanY - stdY;
    final double maxY = meanY + stdY;

    // Iniciar con el estado "Desenfocado" como predeterminado
    String focusState = 'Q0';

    for (final object in objects) {
      final left = object.boundingBox.left;
      final top = object.boundingBox.top;
      final right = object.boundingBox.right;
      final bottom = object.boundingBox.bottom;

      // Calcular el centro del bounding box
      final centerX = (left + right) / 2;
      final centerY = (top + bottom) / 2;

      // Verificar si el centro del bounding box está dentro del rango enfocado
      final bool isFocused = centerX >= minX && centerX <= maxX && centerY >= minY && centerY <= maxY;
      if (isFocused) {
        focusState = 'Q1';
        break;
      } else {
        // Determinar el cuadrante para los objetos desenfocados
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

    // Devolver el estado del enfoque y ubicación
    return focusState;
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

      if(currentTag != 'Calibrate') {
        for (final barcode in barcodes) {
          final centerX = (barcode.boundingBox.left + barcode.boundingBox.right) / 2;
          final centerY = (barcode.boundingBox.top + barcode.boundingBox.bottom) / 2;
          final Offset newPoint = Offset(centerX, centerY);

          // Solo añade si el nuevo punto no existe en la lista actual del tag
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

    // Release the busy lock and redraw the widget
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}
