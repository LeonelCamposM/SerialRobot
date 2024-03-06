import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'serial_service.dart';

class SerialRobotView extends StatefulWidget {
  const SerialRobotView({super.key});

  @override
  State<SerialRobotView> createState() => _SerialRobotView();
}

class _SerialRobotView extends State<SerialRobotView> {
  final SerialService _serialService = SerialService();
  final TextEditingController _textController = TextEditingController();
  
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
    super.dispose();
  }

  void _sendSerialData(String command) {
    _serialService.sendSerialData(command);
  }

  void _sendCommandSequence() async {
  final List<String> commands = ['up', 'up', 'stop']; 
  for (String command in commands) {
    _serialService.sendSerialData(command);
    await Future.delayed(Duration(milliseconds: 500));
  }
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
                    onPressed: () => _serialService.connectTo(device),
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
          onPressed: _sendCommandSequence,
          child: Text('Execute Sequence'),
        ),
      ],
    );
  }
}
