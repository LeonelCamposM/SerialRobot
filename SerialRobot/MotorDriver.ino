const int motorAInput1 = D10;  // Motor A
const int motorAInput2 = D9;
const int motorAPWM = D8;
const int motorBInput1 = D5;  // Motor B
const int motorBInput2 = D6;
const int motorBPWM = D7;
const int stbyPin = D4;  // Standby

void SetupMotorDriver() {
  pinMode(motorAInput1, OUTPUT);
  pinMode(motorAInput2, OUTPUT);
  pinMode(motorAPWM, OUTPUT);
  pinMode(motorBInput1, OUTPUT);
  pinMode(motorBInput2, OUTPUT);
  pinMode(motorBPWM, OUTPUT);
  pinMode(stbyPin, OUTPUT);
  digitalWrite(stbyPin, HIGH);
}

void controlMotorA(bool direction, int speed) {
  digitalWrite(motorAInput1, direction);
  digitalWrite(motorAInput2, !direction);
  analogWrite(motorAPWM, speed);
}

void controlMotorB(bool direction, int speed) {
  digitalWrite(motorBInput1, direction);
  digitalWrite(motorBInput2, !direction);
  analogWrite(motorBPWM, speed);
}

void goForward(int speed) {
  controlMotorA(false, speed);
  controlMotorB(false, speed);
}

void goBackward(int speed) {
  controlMotorA(true, speed);
  controlMotorB(true, speed);
}

void goRight(int speed) {
  controlMotorA(false, speed);
  controlMotorB(true, speed);
}

void goLeft(int speed) {
  controlMotorA(true, speed);
  controlMotorB(false, speed);
}

void stopMovement() {
  controlMotorA(false, 0);
  controlMotorB(false, 0);
}
