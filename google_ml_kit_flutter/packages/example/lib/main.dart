import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

import 'nlp_detector_views/entity_extraction_view.dart';
import 'nlp_detector_views/language_identifier_view.dart';
import 'nlp_detector_views/language_translator_view.dart';
import 'nlp_detector_views/smart_reply_view.dart';
import 'vision_detector_views/barcode_scanner_view.dart';
import 'vision_detector_views/digital_ink_recognizer_view.dart';
import 'vision_detector_views/face_detector_view.dart';
import 'vision_detector_views/face_mesh_detector_view.dart';
import 'vision_detector_views/label_detector_view.dart';
import 'vision_detector_views/object_detector_view.dart';
import 'vision_detector_views/pose_detector_view.dart';
import 'vision_detector_views/selfie_segmenter_view.dart';
import 'vision_detector_views/text_detector_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
      appBar: AppBar(
        title: Text('Google ML Kit Demo App'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          MyApp2(),
          MLKitView()
        ],
      ),
    ));
  }
}
class MLKitView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ExpansionTile(
                      title: const Text('Vision APIs'),
                      children: [
                        CustomCard('Barcode Scanning', BarcodeScannerView()),
                        CustomCard('Face Detection', FaceDetectorView()),
                        CustomCard('Face Mesh Detection', FaceMeshDetectorView()),
                        CustomCard('Image Labeling', ImageLabelView()),
                        CustomCard('Object Detection', ObjectDetectorView()),
                        CustomCard('Text Recognition', TextRecognizerView()),
                        CustomCard('Digital Ink Recognition', DigitalInkView()),
                        CustomCard('Pose Detection', PoseDetectorView()),
                        CustomCard('Selfie Segmentation', SelfieSegmenterView()),
                      ],
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    ExpansionTile(
                      title: const Text('Natural Language APIs'),
                      children: [
                        CustomCard('Language ID', LanguageIdentifierView()),
                        CustomCard(
                            'On-device Translation', LanguageTranslatorView()),
                        CustomCard('Smart Reply', SmartReplyView()),
                        CustomCard('Entity Extraction', EntityExtractionView()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class CustomCard extends StatelessWidget {
  final String _label;
  final Widget _viewPage;
  final bool featureCompleted;

  const CustomCard(this._label, this._viewPage, {this.featureCompleted = true});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: Theme.of(context).primaryColor,
        title: Text(
          _label,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          if (!featureCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    const Text('This feature has not been implemented yet')));
          } else {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => _viewPage));
          }
        },
      ),
    );
  }
}

class MyApp2 extends StatefulWidget {
  const MyApp2({super.key});

  
  @override
  _MyAppState2 createState() => _MyAppState2();
}

class _MyAppState2 extends State<MyApp2> {
  UsbPort? _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  final List<Widget> _serialData = [];

  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDevice? _device;


  bool _handleKeyboardEvent(KeyEvent event) {
    // Check if the key is down event
    if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Handle D-pad Up
        print('D-pad Up pressed');
        _sendSerialData('up');
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Handle D-pad Down
        print('D-pad Down pressed');
        _sendSerialData('down');
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Handle D-pad Left
        print('D-pad Left pressed');
        _sendSerialData('left');
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Handle D-pad Right
        print('D-pad Right pressed');
        _sendSerialData('right');
        return true;
      }
      // Add other keys mapping here
    } else if (event is KeyUpEvent) {
        print('stop pressed');
        _sendSerialData('stop');
      return false;
    }
    // If the event is neither KeyDownEvent nor KeyUpEvent, return false.
    return false;
  }

  Future<bool> _connectTo(device) async {
    HardwareKeyboard.instance.addHandler(_handleKeyboardEvent);
    _serialData.clear();

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      _device = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      setState(() {
        _status = "Failed to open port";
      });
      return false;
    }
    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(_port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen((String line) {
      setState(() {
        _serialData.add(Text(line));
        if (_serialData.length > 20) {
          _serialData.removeAt(0);
        }
      });
    });

   

    setState(() {
      _status = "Connected";
    });
    return true;
  }
  Future<void> _sendSerialData(String command) async {
    if (_port == null) {
      print('Serial port is not connected.');
      return;
    }
    String data = "$command\r\n";
    await _port!.write(Uint8List.fromList(data.codeUnits));
    print('sendend');
    print(command);
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!devices.contains(_device)) {
      _connectTo(null);
    }
    print(devices);

    for (var device in devices) {
      _ports.add(ListTile(
          leading: const Icon(Icons.usb),
          title: Text(device.productName!),
          subtitle: Text(device.manufacturerName!),
          trailing: ElevatedButton(
            child: Text(_device == device ? "Disconnect" : "Connect"),
            onPressed: () {
              _connectTo(_device == device ? null : device).then((res) {
                _getPorts();
              });
            },
          )));
    }

    setState(() {
      print(_ports);
    });
  }

  @override
  void initState() {
    super.initState();

    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();
  }

  @override
  void dispose() {
    super.dispose();
    _connectTo(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
        Text(_ports.isNotEmpty ? "Available Serial Ports" : "No serial devices available", style: Theme.of(context).textTheme.titleLarge),
        ..._ports,
        Text('Status: $_status\n'),
        Text('info: ${_port.toString()}\n'),
        Text("Result Data", style: Theme.of(context).textTheme.titleLarge),
        ..._serialData,
      ]);
  }
}