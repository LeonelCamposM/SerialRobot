import 'package:flutter/services.dart';

import 'serial_service.dart';

class GamepadService {
  late SerialService serialService;
  
  GamepadService(SerialService service) {
    serialService = service;
    HardwareKeyboard.instance.addHandler(handleKeyboardEvent);
  }

  bool handleKeyboardEvent(KeyEvent event) {
    // Check if the key is down event
    if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Handle D-pad Up
        print('D-pad Up pressed');
        serialService.sendSerialData('up');
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Handle D-pad Down
        print('D-pad Down pressed');
        serialService.sendSerialData('down');
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Handle D-pad Left
        print('D-pad Left pressed');
        serialService.sendSerialData('left');
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Handle D-pad Right
        print('D-pad Right pressed');
        serialService.sendSerialData('right');
        return true;
      }
      // Add other keys mapping here
    } else if (event is KeyUpEvent) {
        print('stop pressed');
        serialService.sendSerialData('stop');
      return false;
    }
    // If the event is neither KeyDownEvent nor KeyUpEvent, return false.
    return false;
  }

  void dispose() {
    serialService.dispose();
    HardwareKeyboard.instance.removeHandler(handleKeyboardEvent);
  }
}