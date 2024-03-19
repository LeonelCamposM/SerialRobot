import 'dart:async';
import 'package:flutter/material.dart';
import 'serial_robot_views/serial_robot_view.dart';
import 'vision_detector_views/barcode_scanner_view.dart';

final StreamController<String> focusStateController = StreamController<String>.broadcast();

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
        title: Text('QR Traking robot'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          SerialRobotView(focusStateController: focusStateController),
          CustomCard('Barcode Scanning', BarcodeScannerView(focusStateController: focusStateController))
        ],
      ),
    ));
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