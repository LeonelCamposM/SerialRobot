import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart'; 

class SerialService {
  UsbPort? _port;
  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  String sensorsData = '';
  
  final _portsController = StreamController<List<UsbDevice>>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _dataController = StreamController<String>.broadcast();
  Stream<List<UsbDevice>> get portsStream => _portsController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get dataStream => _dataController.stream;

  Future<bool> connectTo(UsbDevice? device) async {
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
      _statusController.add('Disconnected');
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      _statusController.add('Failed to open port');
      return false;
    }

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(_port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen(_handleResponseData);

    _statusController.add('Connected');
    return true;
  }

  void _handleResponseData(String line) {
    try {
      final jsonData = json.decode(line);
      _dataController.add(json.encode(jsonData));
    } catch (e) {
      _dataController.add('Error parsing JSON: $e');
    }
  }

  Future<void> sendSerialData(String command) async {
    if (_port == null) {
      print('Serial port is not connected.');
      return;
    }
    final String data = '$command\r\n';
    await _port!.write(Uint8List.fromList(data.codeUnits));
  }

  void getPorts() async {
    final List<UsbDevice> devices = await UsbSerial.listDevices();
    _portsController.add(devices);
  }

  void dispose() {
    _subscription?.cancel();
    _transaction?.dispose();
    _port?.close();
    _portsController.close();
    _statusController.close();
    _dataController.close();
  }
}
