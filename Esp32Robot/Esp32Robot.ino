#define DEBUG 1
#include <WiFi.h>
const char* ssid = "xiaoCar";
const char* password = "12345xiao";

// Static IP configuration for the soft AP
IPAddress local_IP(192, 168, 4, 1);
IPAddress gateway(192, 168, 4, 1);
IPAddress subnet(255, 255, 255, 0);

int robotSpeed = 255;
const String robot_type = "DIY";

void startCameraServer();
int getDistance();
int isRightLineDetected();
int isLeftLineDetected();
void setupSensors();
void executeSumoBot();

//Vehicle Control
int ctrl_left = 0;
int ctrl_right = 0;
extern String WiFiAddr = "";

void printSensorsData(){
  String distance = String(getDistance());
  String rightLineDetected = String(isRightLineDetected());
  String leftLineDetected = String(isLeftLineDetected());
  Serial.println("{\"distance\":" + distance + ", \"rightLineDetected\":" + rightLineDetected + ", \"leftLineDetected\":" + leftLineDetected + "}");
}

 void process_feature_msg() {
  String msg = "f" + robot_type + ":";
  msg += "s:";
  sendData(msg);
} 

void sendData(String data) {
  Serial.print(data);
  Serial.println();
}

// Assuming command is in the form "c<left>,<right>"
// Remove the leading 'c' and parse the left and right values
void process_ctrl_msg(String command) { 
  command.remove(0, 1); 
  int commaIndex = command.indexOf(',');  
  int leftValue = command.substring(0, commaIndex).toInt();  
  int rightValue = command.substring(commaIndex + 1).toInt();  

  ctrl_left = constrain(leftValue, -255, 255);
  ctrl_right = constrain(rightValue, -255, 255);
}


void setup() {
  Serial.begin(115200);
  Serial.println();
  setupCamera();
  setupMotorDriver();
  setupSensors();
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH);
}

void setupWebServer(){
  // Configure the soft AP with a static IP address
  WiFi.softAPConfig(local_IP, gateway, subnet);
  WiFi.softAP(ssid, password);
  Serial.print("AP IP address: ");
  Serial.println(local_IP);
  startCameraServer();
  Serial.print("Camera Ready! Use 'http://");
  Serial.print(local_IP);
  WiFiAddr = local_IP.toString();
  Serial.println("' to connect");
}

void loop() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    if (command.startsWith("f")) {
      process_feature_msg();
    }else if (command.startsWith("c")) {
      process_ctrl_msg(command);
    }else if (command.startsWith("s")) {
      while( true) {
        executeSumoBot();
      }
    }else if (command.startsWith("w")) {
      setupWebServer();
    }else {
      Serial.println("{\"error\":\"Invalid command "+ command + "\"}");
    }
    controlMotorA(ctrl_left);
    controlMotorB(ctrl_right);
  }
}