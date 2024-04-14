#define TRIG_PIN D2
#define ECHO_PIN D3
#define RIGHT_SENSOR D0
#define LEFT_SENSOR D1

void setupSensors() {
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

int getDistance() {
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH);
  int distance = duration / 58.2;
  return distance;
}

int isRightLineDetected() {
  return digitalRead(RIGHT_SENSOR);
}

int isLeftLineDetected() {
  return digitalRead(LEFT_SENSOR);
}
