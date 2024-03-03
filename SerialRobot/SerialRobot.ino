
void setup() {
  Serial.begin(115200);
  Serial.println();
  SetupMotorDriver();
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
      Serial.println("down2");
    } else if (command == "left") {
      goLeft();
    } else if (command == "right") {
      goRight();
    } else if (command == "stop") {
      stopMovement();
      Serial.println("stop2");
    } else {
      Serial.println("Invalid command");
    }
  }
}

