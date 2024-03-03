void SetupStrategy() {
  SetupMotorControl();
  SetupSensors();
}

void scanForEnemies() {
  unsigned long start = millis();
  while (true) {
    if (millis() - start >= 2500) {
      stop();
      break;
    }
    int distance = getDistance();
    if (distance <= 40) {
      stop();
      break;
    } else {
      turnLeft(150);
    }
    delay(1);
  }
}


void execute() {
  if (isFrontLineDetected() || isBackLineDetected()) {
    Serial.println("stop");
    stop();
    moveBackward(255);
    delay(800);
    scanForEnemies();
  } else {
    int distance = getDistance();
    if (distance <= 40) {
      digitalWrite(LED_BUILTIN, LOW);
      moveForward(255);
    } else {
      digitalWrite(LED_BUILTIN, HIGH);
      moveForward(150);
    }
  }
}