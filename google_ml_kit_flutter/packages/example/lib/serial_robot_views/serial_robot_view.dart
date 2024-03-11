import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'gamepad_service.dart';
import 'serial_service.dart';

class SerialRobotView extends StatefulWidget {
  const SerialRobotView({super.key});

  @override
  State<SerialRobotView> createState() => _SerialRobotView();
}

class _SerialRobotView extends State<SerialRobotView> {
  final SerialService _serialService = SerialService();
  final TextEditingController _textController = TextEditingController();
  StreamSubscription<String>? _streamSubscription;
  GamepadService? _gamepadService;

  String robotState = 'none';
  @override
  void initState() {
    super.initState();
    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _serialService.getPorts();
    });
    _serialService.getPorts();
  }

  @override
  void dispose() {
    _textController.dispose();
    _serialService.dispose();
    _streamSubscription?.cancel();
    _gamepadService?.dispose();
    super.dispose();
  }

  void _sendSerialData(String command) {
    _serialService.sendSerialData(command);
  }

  void _sendCommandSequence() async {
    final List<String> commands = ['up', 'up', 'stop']; 
    for (final String command in commands) {
      _serialService.sendSerialData(command);
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  Future<void> _sendCommandWithDelay(String command, Duration delay) async {
    _sendSerialData(command); 
    await Future.delayed(delay); 
  }

  void _connectToDevice(UsbDevice device) async {
    final bool connected = await _serialService.connectTo(device);
    if (connected) {
      _gamepadService = GamepadService(_serialService);
    }
  }

  // Delayed desicion making, robot must be careful
  void sumoBot() {
  _streamSubscription?.cancel();
  _streamSubscription = _serialService.dataStream.listen((data) async {
    final Map<String, dynamic> sensorData = json.decode(data);
    final int rightLineDetected = sensorData['rightLineDetected'];
    final int leftLineDetected = sensorData['leftLineDetected'];
    final int distance = sensorData['distance'];
    if (distance < 40) {
      setState(() {
        robotState = 'Stopped due to close object.';
      });
      await _sendCommandWithDelay('stop', Duration(milliseconds: 500));
    } else if (rightLineDetected == 1 || leftLineDetected  == 1) {
      setState(() {
        robotState = 'Turning right due to line detected.';
      });
      await _sendCommandWithDelay('stop', Duration(milliseconds: 500));
      await _sendCommandWithDelay('set_speed 255', Duration(milliseconds: 0));
      await _sendCommandWithDelay('down', Duration(milliseconds: 500));
      await _sendCommandWithDelay('right', Duration(milliseconds: 500));
    } else {
        setState(() {
        robotState = 'Moving forward.';
      });
      await _sendCommandWithDelay('set_speed 180', Duration(milliseconds: 0));
      await _sendCommandWithDelay('up', Duration(milliseconds: 500));
    }
    _sendSerialData('sensors');
  });

  _sendSerialData('sensors');
  setState(() {
    robotState = 'Requesting sensor data...';
  });
}


  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        StreamBuilder<List<UsbDevice>>(
          stream: _serialService.portsStream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return Column(
                children: snapshot.data!.map((device) => ListTile(
                  leading: Icon(Icons.usb),
                  title: Text(device.productName ?? 'Unknown device'),
                  subtitle: Text(device.manufacturerName ?? 'Unknown manufacturer'),
                  trailing: ElevatedButton(
                    child: Text('Connect'),
                    onPressed: () => {
                     _connectToDevice(device)
                    }
                  ),
                )).toList(),
              );
            } else {
              return Text('No serial devices available');
            }
          },
        ),
        StreamBuilder<String>(
          stream: _serialService.statusStream,
          builder: (context, snapshot) {
            return Text('Status: ${snapshot.data ?? 'Idle'}\n');
          },
        ),
        StreamBuilder<String>(
          stream: _serialService.dataStream,
          builder: (context, snapshot) {
            return Text('Data: ${snapshot.data ?? 'N/A'}\n');
          },
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _textController,
            decoration: InputDecoration(
              labelText: 'Enter command',
              suffixIcon: IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  _sendSerialData(_textController.text);
                  _textController.clear(); 
                },
              ),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: ()=> {_sendSerialData('sumo')},
          child: Text('Start sumobot'),
        ),
        ElevatedButton(
          onPressed: ()=> {_sendSerialData('start_stream')},
          child: Text('Start stream'),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Robot state: $robotState'),
        ),
      ],
    );
  }
}
