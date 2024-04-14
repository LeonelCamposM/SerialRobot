const int motorAInput1 = D10;  // Motor A
const int motorAInput2 = D9;
const int motorAPWM = D8;
const int motorBInput1 = D5;  // Motor B
const int motorBInput2 = D6;
const int motorBPWM = D7;
const int stbyPin = D4;  // Standby

void setupMotorDriver() {
  pinMode(motorAInput1, OUTPUT);
  pinMode(motorAInput2, OUTPUT);
  pinMode(motorAPWM, OUTPUT);
  pinMode(motorBInput1, OUTPUT);
  pinMode(motorBInput2, OUTPUT);
  pinMode(motorBPWM, OUTPUT);
  pinMode(stbyPin, OUTPUT);
  digitalWrite(stbyPin, HIGH);
}

void controlMotorA(int value) {
  if (value > 0) {
    digitalWrite(motorAInput1, HIGH);
    digitalWrite(motorAInput2, LOW);
  } else if (value < 0) {
    digitalWrite(motorAInput1, LOW);
    digitalWrite(motorAInput2, HIGH);
    value = -value;
  } else {
    digitalWrite(motorAInput1, LOW);
    digitalWrite(motorAInput2, LOW);
  }
  analogWrite(motorAPWM, value);
}

void controlMotorB(int value) {
  if (value > 0) {
    digitalWrite(motorBInput1, HIGH);
    digitalWrite(motorBInput2, LOW);
  } else if (value < 0) {
    digitalWrite(motorBInput1, LOW);
    digitalWrite(motorBInput2, HIGH);
    value = -value; 
  } else {
    digitalWrite(motorBInput1, LOW);
    digitalWrite(motorBInput2, LOW);
  }
  analogWrite(motorBPWM, value);
}

void stop() {
  controlMotorA(0);  
  controlMotorB(0);  
}

void moveForward(int speed) {
  controlMotorA(speed);  
  controlMotorB(speed);   
}

void moveBackward(int speed) {
  controlMotorA(-speed);   
  controlMotorB(-speed); 
}  

void turnRight(int speed) {
  controlMotorA(speed);   
  controlMotorB(-speed); 
}

void turnLeft(int speed) {
  controlMotorA(-speed);   
  controlMotorB(speed); 
}