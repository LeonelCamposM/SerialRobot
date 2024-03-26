bool shouldStream = false;
int robotSpeed = 255;
const char MAX_MSG_SZ = 60;
char msg_buf[MAX_MSG_SZ] = "";
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
  Serial.print("Heartbeat Interval: ");
  Serial.println(heartbeat_interval);
}

void sendData(String data) {
  Serial.print(data);
  Serial.println();
}

void process_ctrl_msg() {
  char *tmp;                    // this is used by strtok() as an index
  tmp = strtok(msg_buf, ",:");  // replace delimiter with \0
  ctrl_left = atoi(tmp);        // convert to int
  tmp = strtok(NULL, ",:");     // continues where the previous call left off
  ctrl_right = atoi(tmp);       // convert to int
#if DEBUG
  Serial.print("Control: ");
  Serial.print(ctrl_left);
  Serial.print(",");
  Serial.println(ctrl_right);
#endif
}

void setup() {
  Serial.begin(115200);
  Serial.println();
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
    } else if (command == "sensors") {
      printSensorsData();
    } else if (command.startsWith("f")) {
      process_feature_msg();
    }else if (command.startsWith("h")) {
      int interval = command.substring(10).toInt();
      process_heartbeat_msg(interval);
    }else {
      shouldStream = false;
      Serial.println("{\"error\":\"Invalid command "+ command + "\"}");
    }
    if(shouldStream) {
      printSensorsData();
    }
  }
}