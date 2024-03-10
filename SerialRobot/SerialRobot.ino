bool shouldStream = false;
int robotSpeed = 255;

void setup() {
  Serial.begin(115200);
  Serial.println();
  SetupMotorDriver();
  SetupCamera();
  SetupSensors();
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH);
}

void sendInParts(String data, int partSize) {
  for (int i = 0; i < data.length(); i += partSize) {
    String part = data.substring(i, min((unsigned int)(i + partSize), data.length()));
    Serial.print("{\"part\":\"");
    Serial.print(part);
    if (i + partSize < data.length()) {
      Serial.println("\",\"cont\":true}");
    } else {
      // Indica que esta es la última parte
      Serial.println("\",\"end\":true}");
    }
  }
}

void loop() {
  if (Serial.available() > 0) {
    // Read the incoming string until a newline character is received
    String command = Serial.readStringUntil('\n');

    // Remove any whitespace or carriage return characters
    command.trim();

    // Decide the action based on the command
    if (command == "start_stream") {
      shouldStream = true;
    } else if (command == "stop_stream") {
      shouldStream = false;
    }else if (command.startsWith("set_speed")) {
      int speed = command.substring(10).toInt();
      robotSpeed = speed;
    }
    else if (command == "up") {
      goForward(robotSpeed);
    } else if (command == "down") {
      goBackward(robotSpeed);
    } else if (command == "left") {
      goLeft(robotSpeed);
    } else if (command == "right") {
      goRight(robotSpeed);
    } else if (command == "stop") {
      stopMovement();
    } else if (command == "photo") {
      String photoInfo = takePhoto();
      sendInParts(photoInfo, 200); 
    }  else if (command == "sensors") {
      String distance = String(getDistance());
      String frontLineDetected = String(isFrontLineDetected());
      String backLineDetected = String(isBackLineDetected());
      Serial.println("{\"distance\":" + distance + ", \"rightLineDetected\":" + frontLineDetected + ", \"leftLineDetected\":" + backLineDetected + "}");
    }  else if (command == "sumo") {
      while (true) {
        // Realtime desicion making
        int distance = getDistance();
        String frontLineDetected = String(isFrontLineDetected());
        String backLineDetected = String(isBackLineDetected());
        if (isFrontLineDetected() == 1 || isBackLineDetected() == 1) {
          digitalWrite(LED_BUILTIN, HIGH);
          stopMovement();
          goBackward(255);
          delay(800);
          goRight(120);
          delay(500);
        } else {
          if (distance <= 80) {
            digitalWrite(LED_BUILTIN, LOW);
            goForward(255);
          } else {
            digitalWrite(LED_BUILTIN, HIGH);
            goForward(180);
          }
        }
      }
    } else {
      shouldStream = false;
      Serial.println("{\"error\":\"Invalid command "+ command + "\"}");
    }
  }
  if(shouldStream) {
    String distance = String(getDistance());
    String frontLineDetected = String(isFrontLineDetected());
    String backLineDetected = String(isBackLineDetected());
    Serial.println("{\"distance\":" + distance + ", \"rightLineDetected\":" + frontLineDetected + ", \"leftLineDetected\":" + backLineDetected + "}");
  }
}

