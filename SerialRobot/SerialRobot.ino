void setup() {
  Serial.begin(115200);
  Serial.println();
  SetupMotorDriver();
  SetupCamera();
  SetupSensors();
}

void loop() {
  if (Serial.available() > 0) {
    // Read the incoming string until a newline character is received
    String command = Serial.readStringUntil('\n');

    // Remove any whitespace or carriage return characters
    command.trim();

    // Decide the action based on the command
    if (command == "up") {
      goForward();
    } else if (command == "down") {
      goBackward();
    } else if (command == "left") {
      goLeft();
    } else if (command == "right") {
      goRight();
    } else if (command == "stop") {
      stopMovement();
    } else if (command == "photo") {
      String photoInfo = takePhoto();
      Serial.println("{\"img\":\"" + photoInfo + "\"}");
    }  else if (command == "sensors") {
      String distance = String(getDistance());
      String frontLineDetected = String(isFrontLineDetected());
      String backLineDetected = String(isBackLineDetected());
      Serial.println("{\"distance\":" + distance + ", \"frontLineDetected\":" + frontLineDetected + ", \"backLineDetected\":" + backLineDetected + "}");
    } else {
      Serial.println("{\"error\":\"Invalid command\"}");
    }
  }
}

