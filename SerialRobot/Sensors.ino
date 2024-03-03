// Define the sensor pins as constants or macros
#define TRIG_PIN D2
#define ECHO_PIN D3
#define FRONT_SENSOR D0
#define BACK_SENSOR D1


// Constructor
void SetupSensors() {
  // Initialize the distance sensor pins
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

// Method to read the distance from the ultrasonic sensor
int getDistance() {
  // Send a pulse to trigger the sensor
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  // Read the echo duration in microseconds
  long duration = pulseIn(ECHO_PIN, HIGH);

  // Calculate distance in centimeters
  int distance = duration / 58.2;

  return distance;
}

// Method to check if the line is detected by the front sensor
bool isFrontLineDetected() {
  return digitalRead(FRONT_SENSOR) == HIGH;
}

// Method to check if the line is detected by the back sensor
bool isBackLineDetected() {
  return digitalRead(BACK_SENSOR) == HIGH;
}
