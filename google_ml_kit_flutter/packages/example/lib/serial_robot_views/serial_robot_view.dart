import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'gamepad_service.dart';
import 'serial_service.dart';

class SerialRobotView extends StatefulWidget {
  final StreamController<String> focusStateController;
  SerialRobotView({Key? key, required this.focusStateController}) : super(key: key);

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
    widget.focusStateController.stream.listen((data) async {
      if (data == 'Q1' || data == 'Q0') {
        print('focused, dont move $data');
        await _sendCommandWithDelay('stop',  Duration.zero);
      } else if (data == 'Q4') {
        print('unfocused, moving left$data');
        await _sendCommandWithDelay('left',  Duration.zero);
      } else if (data == 'Q5') {
        print('unfocused, moving right$data');
        await _sendCommandWithDelay('right',  Duration.zero);
      } else if (data == 'Q2') {
        print('unfocused, moving up$data');
        await _sendCommandWithDelay('up',  Duration.zero);
      } else if (data == 'Q3') {
        print('unfocused, moving up $data');
        await _sendCommandWithDelay('up',  Duration.zero);
      }
    });
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

  void sumoBot() {
    _streamSubscription?.cancel();
    _streamSubscription = _serialService.dataStream.listen((data) async {
    final Map<String, dynamic> sensorData = json.decode(data);
    final int rightLineDetected = sensorData['rightLineDetected'];
    final int leftLineDetected = sensorData['leftLineDetected'];
    final int distance = sensorData['distance'];

    if (rightLineDetected == 1 || leftLineDetected == 1) {
      setState(() {
        robotState = 'Stopped due to line';
      });
      await _sendCommandWithDelay('stop',  Duration.zero);
      await _sendCommandWithDelay('set_speed 255',  Duration.zero);
      await _sendCommandWithDelay('down',  Duration(milliseconds: 800));
      await _sendCommandWithDelay('set_speed 180',  Duration.zero);
      await _sendCommandWithDelay('right',  Duration(milliseconds: 500));
    }else{
      if (distance <= 80) {
        setState(() {
          robotState = 'Moving forward. at 255';
        });
        await _sendCommandWithDelay('set_speed 255',  Duration.zero);
        await _sendCommandWithDelay('up',  Duration.zero);
      } else {
        setState(() {
          robotState = 'Moving forward. at 180';
        });
        await _sendCommandWithDelay('set_speed 180',  Duration.zero);
        await _sendCommandWithDelay('up',  Duration.zero);
      }
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
              return PaddedRowText(
              text: 'No serial devices available',
            ); 
            }
          },
        ),
        StreamBuilder<String>(
          stream: _serialService.statusStream,
          builder: (context, snapshot) {
            return PaddedRowText(
              text: 'Status: ${snapshot.data ?? 'Idle'}\n',
            );
          },
        ),
        PaddedRowText(
          text: 'Robot state: $robotState',
        ),
        StreamBuilder<String>(
          stream: _serialService.dataStream,
          builder: (context, snapshot) {
            return PaddedRowText(
              text: 'Data: ${snapshot.data ?? 'N/A'}\n',
            );
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
          child: Text('Sumobot esp32'),
        ),
        SpeedSlider(onChange: (speed)=> {_sendSerialData('set_speed $speed')})
      ],
    );
  }
}

class PaddedRowText extends StatelessWidget {
  final String text;
  final double horizontalPadding;

  const PaddedRowText({
    Key? key,
    required this.text,
    this.horizontalPadding = 16.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: horizontalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(text))
        ],
      ),
    );
  }
}

class SpeedSlider extends StatefulWidget {
  final Function(int) onChange;
  
  SpeedSlider({required this.onChange});

  @override
  SpeedSliderState createState() => SpeedSliderState();
}

class SpeedSliderState extends State<SpeedSlider> {
  double _currentSliderValue = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Slider(
          value: _currentSliderValue,
          min: 0,
          max: 255,
          divisions: 255,
          label: _currentSliderValue.round().toString(),
          onChanged: (double value) {
            setState(() {
              _currentSliderValue = value;
              widget.onChange(value.toInt());
            });
          },
        ),
        Text(
          'Valor del Slider: ${_currentSliderValue.round()}',
          style: TextStyle(fontSize: 20),
        ),
      ],
    );
  }
}
