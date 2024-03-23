import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'serial_robot_views/serial_robot_view.dart';
import 'vision_detector_views/barcode_scanner_view.dart';

final StreamController<String> focusStateController = StreamController<String>.broadcast();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Establece la orientación preferida del dispositivo a paisaje.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
      appBar: AppBar(
        title: Text('QR Tracking robot'),
        centerTitle: true,
        elevation: 0,
      ),
      body:ListView.builder(
        itemCount: 2,
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return SerialRobotView(focusStateController: focusStateController);
            case 1:
              return CustomButton(
                label: 'Barcode Following',
                viewPage: BarcodeScannerView(focusStateController: focusStateController),
              );
            default:
              return Container(); 
          }
        },
      ),
    ));
  }
}

class CustomButton extends StatelessWidget {
  final String label;
  final Widget viewPage;
  final bool featureCompleted;

  const CustomButton({
    Key? key,
    required this.label,
    required this.viewPage,
    this.featureCompleted = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: ElevatedButton(
        onPressed: () {
          if (!featureCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('This feature has not been implemented yet')),
            );
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => viewPage));
          }
        },
        child: Text(label),
      ),
    );
  }
}

