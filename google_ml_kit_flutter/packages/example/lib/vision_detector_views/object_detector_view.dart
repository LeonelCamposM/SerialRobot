import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import 'detector_view.dart';
import 'painters/aoi_painter.dart';
import 'painters/object_detector_painter.dart';
import 'utils.dart';

class ObjectDetectorView extends StatefulWidget {
  @override
  State<ObjectDetectorView> createState() => _ObjectDetectorView();
}

class _ObjectDetectorView extends State<ObjectDetectorView> {
  ObjectDetector? _objectDetector;
  DetectionMode _mode = DetectionMode.stream;
  bool _canProcess = false;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;
  int _option = 0;
  final _options = {
    'default': '',
    'efficientnet': 'efficientnet.tflite',
  };

  @override
  void dispose() {
    _canProcess = false;
    _objectDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        DetectorView(
          title: 'Object Detector',
          customPaint: _customPaint,
          text: _text,
          onImage: _processImage,
          initialCameraLensDirection: _cameraLensDirection,
          onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
          onCameraFeedReady: _initializeDetector,
          initialDetectionMode: DetectorViewMode.values[_mode.index],
          onDetectorViewModeChanged: _onScreenModeChanged,
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
                    )),
                Spacer(),
              ],
            )),
      ]),
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
              _initializeDetector();
            });
          }
        },
        items: List<int>.generate(_options.length, (i) => i)
            .map<DropdownMenuItem<int>>((option) {
          return DropdownMenuItem<int>(
            value: option,
            child: Text(_options.keys.toList()[option]),
          );
        }).toList(),
      );

  void _onScreenModeChanged(DetectorViewMode mode) {
    switch (mode) {
      case DetectorViewMode.gallery:
        _mode = DetectionMode.single;
        _initializeDetector();
        return;

      case DetectorViewMode.liveFeed:
        _mode = DetectionMode.stream;
        _initializeDetector();
        return;
    }
  }

  void _initializeDetector() async {
    _objectDetector?.close();
    _objectDetector = null;
    print('Set detector in mode: $_mode');

    if (_option == 0) {
      // use the default model
      print('use the default model');
      final options = ObjectDetectorOptions(
        mode: _mode,
        classifyObjects: true,
        multipleObjects: true,
      );
      _objectDetector = ObjectDetector(options: options);
    } else if (_option > 0 && _option <= _options.length) {
      // use a custom model
      // make sure to add tflite model to assets/ml
      final option = _options[_options.keys.toList()[_option]] ?? '';
      final modelPath = await getAssetPath('assets/ml/$option');
      print('use custom model path: $modelPath');
      final options = LocalObjectDetectorOptions(
        mode: _mode,
        modelPath: modelPath,
        classifyObjects: true,
        multipleObjects: false,
      );
      _objectDetector = ObjectDetector(options: options);
    }

    // uncomment next lines if you want to use a remote model
    // make sure to add model to firebase
    // final modelName = 'bird-classifier';
    // final response =
    //     await FirebaseObjectDetectorModelManager().downloadModel(modelName);
    // print('Downloaded: $response');
    // final options = FirebaseObjectDetectorOptions(
    //   mode: _mode,
    //   modelName: modelName,
    //   classifyObjects: true,
    //   multipleObjects: true,
    // );
    // _objectDetector = ObjectDetector(options: options);

    _canProcess = true;
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (_objectDetector == null) return;
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });

    final objects = await _objectDetector!.processImage(inputImage);

    // Verificar si los metadatos de la imagen están disponibles antes de proceder
    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      final Rect aoiRect = Rect.fromCenter(
        center: Offset(inputImage.metadata!.size.width / 2, inputImage.metadata!.size.height / 2),
        width: inputImage.metadata!.size.width * 0.5,
        height: inputImage.metadata!.size.height * 0.5,
      );
      final aoiPainter = AOIPainter(
        imageSize: inputImage.metadata!.size,
        rotation: inputImage.metadata!.rotation,
        cameraLensDirection: _cameraLensDirection,
        aoiRect: aoiRect,
        color: Colors.green
      );
      analyzeObjectsAndDecideActions(objects, inputImage.metadata!);
      final painter = ObjectDetectorPainter(
        objects,
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

  void analyzeObjectsAndDecideActions(List<DetectedObject> objects, InputImageMetadata metadata) {
    for (final object in objects) {
      final left = object.boundingBox.left;
      final top = object.boundingBox.top;
      final right = object.boundingBox.right;
      final bottom = object.boundingBox.bottom;
      final trackingId = object.trackingId;
      final labelsText = object.labels.map((e) => e.text).join(', ');

      // Calcula el centro del objeto y del Área de Interés (AOI)
      final centerX = (left + right) / 2;
      final centerY = (top + bottom) / 2;
      final screenWidth = metadata.size.width;
      final screenHeight = metadata.size.height;
      final aoiCenterX = screenWidth / 2;
      final aoiCenterY = screenHeight / 2;

      String action = '';
      if (centerX < aoiCenterX) {
        action += 'Move Left, ';
      } else if (centerX > aoiCenterX) {
        action += 'Move Right, ';
      }

      if (centerY < aoiCenterY) {
        action += 'Move Up, ';
      } else if (centerY > aoiCenterY) {
        action += 'Move Down, ';
      }

      // Determina si el objeto está cerca o lejos basándose en el tamaño del bounding box
      final objectArea = (right - left) * (bottom - top);
      final screenArea = screenWidth * screenHeight;
      final areaRatio = objectArea / screenArea;

      if (areaRatio > 0.1) { // Si el objeto ocupa más del 10% del área de la pantalla, se considera "cerca"
        action += 'Object is Close';
      } else {
        action += 'Object is Far';
      }

      // Imprimir las acciones recomendadas
      print('Object Tracking ID: $trackingId - Labels: $labelsText - Recommended Action: $action');
    }
  }
}