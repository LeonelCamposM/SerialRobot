bool shouldStream = false;
int robotSpeed = 140;

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
      Serial.println("\",\"end\":true}");
    }
  }
}

void lineFollower() {
  int rightLineDetected = isRightLineDetected(); 
  int leftLineDetected = isLeftLineDetected();  
  if (rightLineDetected == 0 && leftLineDetected == 0) {
    Serial.println("{\"followerstate\":\"noLineDetected" "\"}");
    digitalWrite(LED_BUILTIN, LOW); 
    goForward(120);
    delay(100);
  } else if(leftLineDetected == 1 && rightLineDetected == 1){
    Serial.println("{\"followerstate\":\"bothLinesDetected" "\"}");
    digitalWrite(LED_BUILTIN, HIGH);
    stopMovement();
    delay(100);
  }
  else if (rightLineDetected == 1 && leftLineDetected == 0) {
    Serial.println("{\"followerstate\":\"rightLineDetected" "\"}");
    digitalWrite(LED_BUILTIN, LOW);
    goRight(120);
    delay(100); 
  }
  else if (leftLineDetected == 1 && rightLineDetected == 0) {
    Serial.println("{\"followerstate\":\"leftLineDetected" "\"}");
    digitalWrite(LED_BUILTIN, LOW);
    goLeft(120);
    delay(100); 
  }
}

void sumoBot(){
  int distance = getDistance();
  if (isRightLineDetected() == 1 || isLeftLineDetected() == 1) {
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

void printSensorsData(){
  String distance = String(getDistance());
  String rightLineDetected = String(isRightLineDetected());
  String leftLineDetected = String(isLeftLineDetected());
  Serial.println("{\"distance\":" + distance + ", \"rightLineDetected\":" + rightLineDetected + ", \"leftLineDetected\":" + leftLineDetected + "}");
}

void loop() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();

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
      printSensorsData();
    }  else if (command == "sumo") {
      // Realtime desicion making
      while (true) {
        sumoBot();
      } 
    } else {
      shouldStream = false;
      Serial.println("{\"error\":\"Invalid command "+ command + "\"}");
    }
    if(shouldStream) {
      printSensorsData();
    }
  }
}

