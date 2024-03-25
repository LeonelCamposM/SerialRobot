import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'gamepad_service.dart';
import 'serial_service.dart';

class SerialRobotView extends StatefulWidget {
  final StreamController<String> focusStateController;
  final Widget? additionalButton; 

  SerialRobotView({
    Key? key,
    required this.focusStateController,
    this.additionalButton,
  }) : super(key: key);

  @override
  State<SerialRobotView> createState() => _SerialRobotView();
}

class _SerialRobotView extends State<SerialRobotView> {
  final SerialService _serialService = SerialService();
  final TextEditingController _textController = TextEditingController();
  StreamSubscription<String>? _streamSubscription;
  GamepadService? _gamepadService;
  bool _showTerminal = true; 

  String robotState = 'none';
  @override
  void initState() {
    super.initState();
    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _serialService.getPorts();
    });
    _serialService.getPorts();

    final dynamicAoiCommands = {
      ...generateDynamicAoiCommands([46, 49], 'right', 160, 100, true),
      ...generateDynamicAoiCommands([56, 59], 'right', 160, 100, true),
      ...generateDynamicAoiCommands([40, 43], 'left', 160, 100, false),
      ...generateDynamicAoiCommands([50, 53], 'left', 160, 100,false),
    };

    final aoiCommands = {
      '0-30': AoiCommand([
        {'set_speed 255': Duration.zero},
        {'down': Duration.zero},
      ]),
      '60-100': AoiCommand([
        {'set_speed 255': Duration.zero},
        {'down': Duration.zero},
      ]),
      '44-45': AoiCommand([
        {'set_speed 0': Duration.zero},
        {'stop': Duration.zero}, 
      ]),
      '54-55': AoiCommand([
        {'set_speed 0': Duration.zero},
        {'stop': Duration.zero}, 
      ]),
      ...dynamicAoiCommands,
    };

    widget.focusStateController.stream.listen((data) async {
      if(data == 'Unfocused') {
        await _sendCommandWithDelay('stop',  Duration.zero);
        return;
      }

      final int aoi = int.tryParse(data.replaceAll(RegExp('[^0-9]'), '')) ?? -1;
      if (aoi == -1) return;

      AoiCommand? commandToExecute;

      aoiCommands.forEach((key, value) {
        final range = key.split('-').map(int.parse).toList();
        if (aoi >= range[0] && aoi <= range[1]) {
          commandToExecute = value;
        }
      });

      if (commandToExecute != null) {
        for (final commandMap in commandToExecute!.commands) {
          final command = commandMap.keys.first;
          final delay = commandMap[command]!;
          print('Executing command: $command with delay: ${delay.inMilliseconds}ms data: $data');
          await _sendCommandWithDelay(command, delay);
        }
      } else {
        print('No command found for AOI $aoi');
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

 int calculateSpeed(int aoi, List<int> aoiRange, int maxSpeed, int minSpeed,  bool increasingWithAoi) {
    double fraction;
    if (increasingWithAoi) {
      // Para movimientos donde la velocidad aumenta con el valor de AOI
      fraction = (aoi - aoiRange[0]) / (aoiRange[1] - aoiRange[0]);
    } else {
      // Para movimientos donde la velocidad disminuye con el valor de AOI
      fraction = (aoiRange[1] - aoi) / (aoiRange[1] - aoiRange[0]);
    }
    final int speed = minSpeed + ((maxSpeed - minSpeed) * fraction).round();
    return speed;
  }


  
  Map<String, AoiCommand> generateDynamicAoiCommands(List<int> aoiRange, String action, int maxSpeed, int minSpeed, bool increasingWithAoi) {
    final Map<String, AoiCommand> aoiCommands = {};

    // Ajusta para generar comandos para cada AOI en el rango
    for (int aoi = aoiRange[0]; aoi <= aoiRange[1]; aoi++) {
      int speed = calculateSpeed(aoi, aoiRange, maxSpeed, minSpeed, increasingWithAoi);
      aoiCommands['$aoi-$aoi'] = AoiCommand([
        {'set_speed $speed': Duration.zero},
        {action: Duration.zero},
      ]);
    }

    return aoiCommands;
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
    return ListView(
      children: [
        Column(
        children: <Widget>[
          ListTile(
            title: Text('Mostrar Terminal y Consola'),
            trailing: Switch(
              value: _showTerminal,
              onChanged: (bool value) {
                setState(() {
                  _showTerminal = value;
                });
              },
            ),
          ),
          _showTerminal ?
          // Robot Terminal
          Column(
            children: [
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
            ],
          ): Container(),
      
          // Robot Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: ()=> {_sendSerialData('sumo')},
                child: Text('Sumobot esp32'),
              ),
              if (widget.additionalButton != null) widget.additionalButton!,
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SpeedSlider(onChange: (speed)=> {_sendSerialData('set_speed $speed')}),
          )
        ],
      )
      ]
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Robot speed: ${_currentSliderValue.round()}',
            style: TextStyle(fontSize: 20, ),
          ),
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
        ],
      ),
    );
  }
}

class AoiCommand {
  final List<Map<String, Duration>> commands;
  AoiCommand(this.commands);
}
