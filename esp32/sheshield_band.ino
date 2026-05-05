/*
  ╔═══════════════════════════════════════════════════════════════╗
  ║                  SheShield Bracelet Firmware                  ║
  ║                    ESP32 Microcontroller                      ║
  ║                                                               ║
  ║  Heart Rate Monitor + Accelerometer + Bluetooth Serial       ║
  ║  Sends data to Flutter app via HC-05/HC-06 module            ║
  ╚═══════════════════════════════════════════════════════════════╝

  HARDWARE:
  - ESP32-S3 DevKitC
  - MAX30102 Heart Rate Sensor (I2C)
  - MPU6050 Accelerometer (I2C)
  - Vibration Motor (GPIO 25)
  - Status LED (GPIO 26)
  - Buzzer (GPIO 27)
  - HC-05 Bluetooth Module (RX: GPIO 16, TX: GPIO 17)
  - Battery (4.2V LiPo, 500mAh)

  PROTOCOL:
  - All commands terminated with \n
  - All responses terminated with \n
  - Commands from app: SOS, SHAKE, VIBRATE_SOS, LED_ON, LED_OFF, etc
  - Responses to app: HR_DATA:[bpm], BATTERY:[%], etc
*/

#include <Wire.h>
#include <HardwareSerial.h>

// ========== PIN DEFINITIONS ==========
const int VIBRATION_PIN = 25;
const int LED_PIN = 26;
const int BUZZER_PIN = 27;
const int BT_RX_PIN = 16;
const int BT_TX_PIN = 17;

// ========== SENSOR REGISTERS & ADDRESSES ==========
#define MAX30102_ADDR 0x57
#define MPU6050_ADDR 0x68

// ========== TIMING CONSTANTS ==========
const unsigned long HR_UPDATE_INTERVAL = 2000;    // Send HR every 2 seconds
const unsigned long BATTERY_CHECK_INTERVAL = 5000; // Check battery every 5 seconds
const unsigned long SHAKE_DEBOUNCE = 300;          // Shake debounce time

// ========== STATE VARIABLES ==========
unsigned long lastHRUpdate = 0;
unsigned long lastBatteryCheck = 0;
unsigned long lastShakeTime = 0;

int currentHR = 0;
int batteryLevel = 100;
bool isShaking = false;
bool isSOSActive = false;

// ========== HARDWARE SERIAL FOR BLUETOOTH ==========
HardwareSerial bluetooth(1); // UART1 for Bluetooth

// ========== SETUP ==========
void setup() {
  // Initialize Serial for debugging (USB)
  Serial.begin(115200);
  delay(100);
  Serial.println("\n\n╔═══════════════════════════════╗");
  Serial.println("║  SheShield Bracelet v1.0      ║");
  Serial.println("╚═══════════════════════════════╝\n");

  // Initialize Bluetooth Serial
  bluetooth.begin(9600, SERIAL_8N1, BT_RX_PIN, BT_TX_PIN);
  Serial.println("[INIT] Bluetooth initialized");

  // Initialize pins
  pinMode(VIBRATION_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(VIBRATION_PIN, LOW);
  digitalWrite(LED_PIN, LOW);
  digitalWrite(BUZZER_PIN, LOW);
  Serial.println("[INIT] GPIO pins configured");

  // Initialize I2C for sensors
  Wire.begin(21, 22); // SDA=GPIO21, SCL=GPIO22
  Serial.println("[INIT] I2C initialized");

  // Initialize sensors
  initializeMaxHR();
  initializeMPU6050();

  Serial.println("[INIT] Sensors initialized");
  Serial.println("[READY] Waiting for commands...\n");

  // Startup indication
  indicateStartup();
}

// ========== MAIN LOOP ==========
void loop() {
  // Read Bluetooth commands
  if (bluetooth.available()) {
    String command = bluetooth.readStringUntil('\n');
    command.trim();
    if (command.length() > 0) {
      Serial.println("[CMD RX] " + command);
      handleBluetoothCommand(command);
    }
  }

  // Update heart rate periodically
  if (millis() - lastHRUpdate >= HR_UPDATE_INTERVAL) {
    currentHR = readHeartRate();
    bluetooth.println("HR_DATA:" + String(currentHR));
    Serial.println("[HR] " + String(currentHR) + " BPM");
    lastHRUpdate = millis();
  }

  // Check battery periodically
  if (millis() - lastBatteryCheck >= BATTERY_CHECK_INTERVAL) {
    batteryLevel = readBatteryLevel();
    bluetooth.println("BATTERY:" + String(batteryLevel));
    Serial.println("[BATTERY] " + String(batteryLevel) + "%");
    lastBatteryCheck = millis();
  }

  // Check for shake
  checkForShake();

  delay(10);
}

// ========== BLUETOOTH COMMAND HANDLER ==========
void handleBluetoothCommand(String command) {
  if (command == "SOS") {
    Serial.println("[SOS] SOS received!");
    isSOSActive = true;
    activateSOSAlert();
  } else if (command == "VIBRATE_SOS") {
    Serial.println("[ALERT] Vibrating...");
    vibratePattern();
  } else if (command == "LED_ON") {
    digitalWrite(LED_PIN, HIGH);
    Serial.println("[LED] ON");
  } else if (command == "LED_OFF") {
    digitalWrite(LED_PIN, LOW);
    Serial.println("[LED] OFF");
  } else if (command == "BUZZER_ON") {
    digitalWrite(BUZZER_PIN, HIGH);
    Serial.println("[BUZZER] ON");
  } else if (command == "BUZZER_OFF") {
    digitalWrite(BUZZER_PIN, LOW);
    Serial.println("[BUZZER] OFF");
  } else if (command == "GET_HR") {
    int hr = readHeartRate();
    bluetooth.println("HR_DATA:" + String(hr));
    Serial.println("[HR QUERY] " + String(hr) + " BPM");
  } else if (command == "GET_BATTERY") {
    int battery = readBatteryLevel();
    bluetooth.println("BATTERY:" + String(battery));
    Serial.println("[BATTERY QUERY] " + String(battery) + "%");
  } else if (command == "STEALTH") {
    Serial.println("[STEALTH] Stealth mode activated");
    // Could trigger on-device display change if available
  } else if (command == "PING") {
    bluetooth.println("PONG");
    Serial.println("[PING] PONG");
  } else {
    Serial.println("[WARN] Unknown command: " + command);
  }
}

// ========== SENSOR FUNCTIONS ==========

/// Initialize MAX30102 Heart Rate Sensor
void initializeMaxHR() {
  // Write to FIFO_CONFIG (0x08): Clear FIFO, 16-sample avg
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(0x08);
  Wire.write(0x0F); // Clear FIFO on config
  Wire.endTransmission();

  // Write to MODE_CONFIG (0x09): HR mode
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(0x09);
  Wire.write(0x02); // Heart rate mode
  Wire.endTransmission();

  // Write to LED_PA (0x0C & 0x0D): Set LED power
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(0x0C);
  Wire.write(0x24); // LED1 power
  Wire.write(0x24); // LED2 power
  Wire.endTransmission();

  Serial.println("[SENSOR] MAX30102 initialized");
}

/// Read heart rate from MAX30102 (simplified - real implementation would process FIFO)
int readHeartRate() {
  // Simulate HR reading (50-120 BPM)
  // In real implementation, read FIFO_DATA (0x07) and process signal
  static int simHR = 72;
  simHR += random(-5, 6); // Vary by ±5
  simHR = constrain(simHR, 50, 140);
  return simHR;
}

/// Initialize MPU6050 Accelerometer
void initializeMPU6050() {
  // Wake up MPU6050 (PWR_MGMT_1 = 0x6B)
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x6B);
  Wire.write(0x00);
  Wire.endTransmission();

  // Set accelerometer range (ACCEL_CONFIG = 0x1C)
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x1C);
  Wire.write(0x00); // ±2g range
  Wire.endTransmission();

  Serial.println("[SENSOR] MPU6050 initialized");
}

/// Check for shake gesture (simple threshold)
void checkForShake() {
  // Read accelerometer (ACCEL_XOUT = 0x3B)
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x3B);
  Wire.endTransmission();
  Wire.requestFrom(MPU6050_ADDR, 6);

  int16_t accelX = (Wire.read() << 8) | Wire.read();
  int16_t accelY = (Wire.read() << 8) | Wire.read();
  int16_t accelZ = (Wire.read() << 8) | Wire.read();

  // Calculate magnitude
  int magnitude =
      sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ) / 1024;

  // Threshold for shake (adjust based on testing)
  if (magnitude > 5 && (millis() - lastShakeTime) > SHAKE_DEBOUNCE) {
    Serial.println("[SHAKE] Detected! Magnitude: " + String(magnitude));
    bluetooth.println("SHAKE");
    lastShakeTime = millis();
  }
}

/// Read battery level (via ADC on GPIO 34)
int readBatteryLevel() {
  // ADC on GPIO 34 (Analog input for battery)
  int adcValue = analogRead(34);
  // Convert to percentage (4.2V = 100%, 3.0V = 0%)
  // Max ADC = 4095 (at 3.3V), Battery Max = 4.2V (need voltage divider)
  int percentage = map(adcValue, 660, 880, 0, 100); // Adjust based on divider
  return constrain(percentage, 0, 100);
}

// ========== ALERT PATTERNS ==========

/// Activate full SOS alert (vibration + LED + buzzer)
void activateSOSAlert() {
  Serial.println("[SOS] Starting SOS alert sequence...");

  // SOS pattern: 3 short, 3 long, 3 short
  for (int i = 0; i < 3; i++) {
    vibrateMotor(100);
    digitalWrite(LED_PIN, HIGH);
    digitalWrite(BUZZER_PIN, HIGH);
    delay(150);
    digitalWrite(LED_PIN, LOW);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }

  delay(200);

  for (int i = 0; i < 3; i++) {
    vibrateMotor(300);
    digitalWrite(LED_PIN, HIGH);
    digitalWrite(BUZZER_PIN, HIGH);
    delay(400);
    digitalWrite(LED_PIN, LOW);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }

  delay(200);

  for (int i = 0; i < 3; i++) {
    vibrateMotor(100);
    digitalWrite(LED_PIN, HIGH);
    digitalWrite(BUZZER_PIN, HIGH);
    delay(150);
    digitalWrite(LED_PIN, LOW);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }

  isSOSActive = false;
  Serial.println("[SOS] Alert sequence complete");
}

/// Simple vibration pattern
void vibratePattern() {
  for (int i = 0; i < 3; i++) {
    vibrateMotor(100);
    delay(100);
  }
}

/// Vibrate motor for specified duration
void vibrateMotor(int durationMs) {
  digitalWrite(VIBRATION_PIN, HIGH);
  delay(durationMs);
  digitalWrite(VIBRATION_PIN, LOW);
}

/// Startup indication
void indicateStartup() {
  digitalWrite(LED_PIN, HIGH);
  delay(200);
  digitalWrite(LED_PIN, LOW);
  delay(100);
  digitalWrite(LED_PIN, HIGH);
  delay(200);
  digitalWrite(LED_PIN, LOW);

  vibrateMotor(100);
}

// ========== END OF FIRMWARE ==========
