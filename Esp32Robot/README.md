# ESP32Robot
The goal of this project is to create code for the ESP32 S3 to control motors, gather readings from sensors and the camera, and expose all this functionality through a serial interface.

## Configuration Steps
To prepare your ESP32 in the Arduino IDE, follow these configuration steps:

<table>
<tr>
    <th>Step</th>
    <th>Description</th>
    <th>Image</th>
</tr>
<tr>
    <td>1</td>
    <td>Configure the Arduino board manager to manage the ESP32.</td>
    <td><img src="Img/ArduinoBoardManager.png" alt="Arduino Board Manager" width="600"/></td>
</tr>
<tr>
    <td>2</td>
    <td>Set the OPIPSRAM option (to use the camera on Xiao ESP32-S3 Sense).</td>
    <td><img src="Img/OPIPSRAM.png" alt="OPIPSRAM Setting" width="400"/></td>
</tr>
</table>

## Code Design

The following UML diagram illustrates the architecture of the software system. It includes the key classes, `Esp32Robot`, `MotorDriver`, `Sensors`, and `Camera`.
 
The `Esp32Robot` class is the central unit controlling various functions, depicted by the composition links to `MotorDriver` for motion control, `Sensors` for environmental interaction, and `Camera` for visual data processing. These relationships are crucial for understanding the overall functionality and structure of the robotic system.

<img src="Design/UML.svg" alt="Base Circuit" width="800"/>
