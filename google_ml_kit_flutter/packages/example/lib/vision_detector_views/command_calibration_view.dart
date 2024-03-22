import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'detector_view.dart';
import 'painters/aoi_painter.dart';
import 'painters/barcode_detector_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  
  String currentTag = 'Calibrate';
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
        setState(() async {
          _option = option;
          currentTag = _options[option]!;
          if(currentTag == 'Calibrate Save'){
            print('current storing points: ');
            await saveCalibrationData();
          } else if(currentTag == 'Calibrate Load') {  
            print('current loaded points Q1: ');
            await loadCalibrationData();
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

  Future<void> saveCalibrationData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Serializar taggedPoints a una cadena JSON
    String serializedData = jsonEncode(taggedPoints.map((key, value) => MapEntry(key, value.map((e) => {'dx': e.dx, 'dy': e.dy}).toList())));
    await prefs.setString('calibrationData', serializedData);
  }

  Future<void> loadCalibrationData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? serializedData = prefs.getString('calibrationData');
    if (serializedData != null) {
      Map<String, dynamic> jsonData = jsonDecode(serializedData);
      taggedPoints = jsonData.map((key, value) {
        List<Offset> points = (value as List<dynamic>).map((e) => Offset(e['dx'], e['dy'])).toList();
        return MapEntry(key, points);
      });
    }
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
