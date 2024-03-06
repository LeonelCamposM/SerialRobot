import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart'; 

class SerialRobotView extends StatefulWidget {
  const SerialRobotView({super.key});

  @override
  State<SerialRobotView> createState() => _SerialRobotView();
}

class _SerialRobotView extends State<SerialRobotView> {
  UsbPort? _port;
  String _status = 'Idle';
  List<Widget> _ports = [];
  final List<Widget> _serialData = [];
  final TextEditingController _textController = TextEditingController();

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
        _status = 'Disconnected';
      });
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      setState(() {
        _status = 'Failed to open port';
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
        _handleResponseData(line);
      });
    });

   

    setState(() {
      _status = 'Connected';
    });
    return true;
  }

  // Add a new buffer string to store the incoming data parts
  String _dataBuffer = '';

  void _handleResponseData(String line) {
    try {
      final jsonData = json.decode(line);
      // Check if jsonData contains a part of the image
      if (jsonData.containsKey('part')) {
        // Append the part of the image to the buffer
        _dataBuffer += jsonData['part'];

        // If it's the last part of the image
        if (jsonData.containsKey('end')) {
          // Decode the Base64 string to bytes
          final Uint8List bytes = base64.decode(_dataBuffer);

          // Create an Image widget from bytes
          final Widget image = Image.memory(bytes);

          // Update the UI to display the image
          setState(() {
            _serialData.add(SizedBox(height: 150, width: 150, child: image));
          });

          // Clear the buffer for the next image
          _dataBuffer = '';
        }
      } else {
        // If not a part of the image, process as normal
        setState(() {
          _serialData.add(Text('Data: $jsonData'));
        });
      }
    } catch (e, stackTrace) {
      // Log the error and stack trace for detailed debugging information
      setState(() {
        _serialData.add(Text('Error parsing JSON: $e'));
        _serialData.add(Text('Stack Trace: $stackTrace'));

        // Handle specific error types differently (optional)
        if (e is FormatException) {
          _serialData.add(Text('The provided string is not valid JSON.'));
        } else if (e is TypeError) {
          _serialData.add(Text('The decoded value has an unexpected type.'));
        } else {
          _serialData.add(Text('An unexpected error occurred.'));
        }

        // Optionally, you might want to clear the buffer in case of an error
        _dataBuffer = '';
      });
    }
  }

  Future<void> _sendSerialData(String command) async {
    if (_port == null) {
      print('Serial port is not connected.');
      return;
    }
    final String data = '$command\r\n';
    await _port!.write(Uint8List.fromList(data.codeUnits));
    print('sendend');
    print(command);
  }

  void _getPorts() async {
    _ports = [];
    final List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!devices.contains(_device)) {
      _connectTo(null);
    }
    print(devices);

    for (final device in devices) {
      _ports.add(ListTile(
          leading: const Icon(Icons.usb),
          title: Text(device.productName!),
          subtitle: Text(device.manufacturerName!),
          trailing: ElevatedButton(
            child: Text(_device == device ? 'Disconnect' : 'Connect'),
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
    _textController.dispose(); 
    super.dispose();
    _connectTo(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(_ports.isNotEmpty ? 'Available Serial Ports' : 'No serial devices available', style: Theme.of(context).textTheme.titleLarge),
        ..._ports,
        Text('Status: $_status\n'),
        Text('Info: ${_port.toString()}\n'),
        Text('Result Data', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(
          height: 200, 
          width: 200, 
          child: ListView.builder(
            itemCount: _serialData.length,
            itemBuilder: (context, index) => _serialData[index],
          ),
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
                  _textController.clear(); // Limpia el campo después de enviar
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}