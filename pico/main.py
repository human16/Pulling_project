import bluetooth
import random
import struct
import time

# --- CONSTANTS ---
_SERVICE_UUID = bluetooth.UUID(0x181A)  # Environmental Sensing Service
_CHAR_UUID = bluetooth.UUID(0x2A6C)      # Temperature Characteristic

# --- BLE CONFIGURATION ---
ble = bluetooth.BLE()

# Ensure a clean start
ble.active(False)
time.sleep(0.1)
ble.active(True)
time.sleep(0.1)

# Variable to track connection status manually
is_connected = False 

def create_advertising_packet():
    """Creates a valid BLE advertising payload."""
    name = b"Pico2W-Sensor"
    
    # 1. Flags: Length 2, Type 0x01 (Flags), Value 0x06 (General Discoverable)
    flags = struct.pack("BBB", 2, 0x01, 0x06)
    
    # 2. Service UUID: Length 3, Type 0x03 (16-bit UUID List), Value 0x181A (Little Endian)
    services = struct.pack("BBH", 3, 0x03, 0x181A)
    
    # 3. Name: Length varies, Type 0x09 (Complete Local Name)
    # Length byte is included in the struct pack
    name_bytes = struct.pack(f"BB{len(name)}s", len(name), 0x09, name)
    
    # Combine all parts
    return flags + services + name_bytes

def advertise():
    # THE FIX: Interval must be in MICROSECONDS. 
    # 100ms = 100,000 microseconds.
    # Previous code used 100, which is too fast (0.1ms) and fails.
    adv_payload = create_advertising_packet()
    ble.gap_advertise(100_000, adv_data=adv_payload)

# Register the service
SENSOR_SERVICE = (
    _SERVICE_UUID,
    (
        (_CHAR_UUID, bluetooth.FLAG_READ | bluetooth.FLAG_NOTIFY),
    ),
)

services = [SENSOR_SERVICE]

# Register the services and get the handles
((char_handle,),) = ble.gatts_register_services(services)

# Initialize the characteristic with a starting value
initial_data = struct.pack("<fB", 20.0, 50) 
ble.gatts_write(char_handle, initial_data)

# Setup callbacks
def irqs(handler, data):
    global is_connected 
    
    # 1 = _IRQ_CENTRAL_CONNECT
    if handler == 1: 
        is_connected = True
        print("Phone connected!")
    
    # 2 = _IRQ_CENTRAL_DISCONNECT
    elif handler == 2: 
        is_connected = False
        print("Phone disconnected.")
        advertise() 

ble.irq(irqs)

# Start advertising
advertise()
print("Bluetooth Advertising started. Check System Bluetooth Settings now.")

# --- MAIN LOOP ---
while True:
    # Blink LED so we know code is running
    # (On Pico 2W, onboard LED is usually pin 25, or use LED class if available)
    led = machine.Pin("LED", machine.Pin.OUT)
    
    if is_connected: 
        mock_temp = random.uniform(20.0, 30.0)
        mock_humid = random.randint(40, 60)
        
        payload = struct.pack("<fB", mock_temp, mock_humid)
        ble.gatts_write(char_handle, payload)
        ble.gatts_notify(0, char_handle, payload)
        
        print(f"Sent: Temp {mock_temp:.2f}°C, Humidity {mock_humid}%")
    
    time.sleep(1)