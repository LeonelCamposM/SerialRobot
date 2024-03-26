#define DEBUG 1
bool shouldStream = false;
int robotSpeed = 255;
const String robot_type = "DIY";

//Heartbeat
unsigned long heartbeat_interval = -1;
unsigned long heartbeat_time = 0;

//Vehicle Control
int ctrl_left = 0;
int ctrl_right = 0;


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

void process_heartbeat_msg(int heartbeat_interval) {
  heartbeat_time = millis();
  // Serial.print("Heartbeat Interval: ");
  // Serial.println(heartbeat_interval);
}

void sendData(String data) {
  Serial.print(data);
  Serial.println();
}

// Assuming command is in the form "c<left>,<right>"
// Remove the leading 'c' and parse the left and right values
void process_ctrl_msg(String command) {  // Asegúrate de pasar la cadena de comando como argumento
  command.remove(0, 1); 
  int commaIndex = command.indexOf(',');  
  int leftValue = command.substring(0, commaIndex).toInt();  
  int rightValue = command.substring(commaIndex + 1).toInt();  

  ctrl_left = constrain(leftValue, -255, 255);
  ctrl_right = constrain(rightValue, -255, 255);

  #if DEBUG
    Serial.print("ACK Control: ");
    Serial.print(leftValue);  
    Serial.print(",");
    Serial.println(rightValue); 
  #endif
}


void setup() {
  Serial.begin(115200);
  Serial.println();
  SetupMotorDriver();
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
    } else if (command == "sensors") {
      printSensorsData();
    } else if (command.startsWith("f")) {
      process_feature_msg();
    }else if (command.startsWith("h")) {
      process_heartbeat_msg(22);
    }else if (command.startsWith("c")) {
      process_ctrl_msg(command);
    }else {
      shouldStream = false;
      Serial.println("{\"error\":\"Invalid command "+ command + "\"}");
    }
    if(shouldStream) {
      printSensorsData();
    }
    controlMotorA(ctrl_left);
    controlMotorB(ctrl_right);
  }
}