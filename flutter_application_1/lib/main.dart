import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pico 2W Monitor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SensorScreen(),
    );
  }
}

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  final Guid serviceUuid = Guid("0000181a-0000-1000-8000-00805f9b34fb");
  final Guid charUuid = Guid("00002a6c-0000-1000-8000-00805f9b34fb");

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetCharacteristic;
  
  String tempData = "--";
  String humidityData = "--";

  List<ScanResult> discoveredDevices = [];
  bool isScanning = false;
  bool isConnecting = false; // New: Tracks connection attempt

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      _startScanning();
    } else {
      setState(() => isScanning = false);
      // Simple alert for debug
      print("Permissions Denied");
    }
  }

  void _startScanning() async {
    setState(() {
      isScanning = true;
      discoveredDevices.clear();
    });

    var subscription = FlutterBluePlus.scanResults.listen((results) {
      if (results.isNotEmpty) {
        final seenIds = <String>{}; 
        setState(() {
          discoveredDevices = results.where((r) {
            if (seenIds.contains(r.device.remoteId.toString())) return false;
            seenIds.add(r.device.remoteId.toString());
            return true;
          }).toList();
        });
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    Future.delayed(const Duration(seconds: 10), () => setState(() => isScanning = false));
  }

  void _connectToDevice(BluetoothDevice device) async {
    // 1. Stop Scanning
    FlutterBluePlus.stopScan();
    
    // 2. Show Loading State (This switches the screen view automatically)
    setState(() {
      isConnecting = true;
      targetDevice = null; // Ensure list view is hidden
    });

    try {
      // 3. Connect
      await device.connect(timeout: const Duration(seconds: 15));
      
      // 4. Assign device and switch to Data Screen
      setState(() {
        targetDevice = device;
        isConnecting = false;
      });
      
      _discoverServices(device);
    } catch (e) {
      // Handle failure
      setState(() {
        isConnecting = false;
        _startScanning(); // Go back to scanning
      });
      print("Connection failed: $e");
    }
  }

  void _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == charUuid) {
            targetCharacteristic = characteristic;
            _subscribeToCharacteristic(characteristic);
            break;
          }
        }
      }
    }
  }

  void _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    characteristic.lastValueStream.listen((value) {
      if (value.isNotEmpty) _parseData(value);
    });
  }

  void _parseData(List<int> data) {
    final buffer = ByteData.sublistView(Uint8List.fromList(data));
    double temp = buffer.getFloat32(0, Endian.little);
    int humidity = buffer.getUint8(4);
    setState(() {
      tempData = "$temp °C";
      humidityData = "$humidity %";
    });
  }

  // --- UI BUILDERS ---

  // 1. Scanning Screen (List of devices)
  Widget _buildScanningScreen() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text("Scanning for Pico...", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (isScanning) 
          const Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()),
        
        Expanded(
          child: discoveredDevices.isEmpty 
            ? const Center(child: Text("No devices found.\nMake sure Location is ON."))
            : ListView.builder(
                itemCount: discoveredDevices.length,
                itemBuilder: (context, index) {
                  final d = discoveredDevices[index].device;
                  final name = d.localName.isEmpty ? "Unknown Device" : d.localName;
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(d.remoteId.toString()),
                    trailing: const Icon(Icons.bluetooth, color: Colors.blue),
                    onTap: () => _connectToDevice(d),
                  );
                },
              ),
        ),
      ],
    );
  }

  // 2. Connecting Screen (Loading spinner)
  Widget _buildConnectingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text("Connecting...", style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  // 3. Data Screen (Temperature & Humidity)
  Widget _buildDataScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Connected to Pico 2W", style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 40),
          
          // Temperature
          const Icon(Icons.thermostat, size: 80, color: Colors.orange),
          Text(tempData, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
          
          const SizedBox(height: 60),
          
          // Humidity
          const Icon(Icons.water_drop, size: 80, color: Colors.blue),
          Text(humidityData, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
          
          const SizedBox(height: 80),
          
          // Disconnect Button
          ElevatedButton.icon(
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text("Disconnect"),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            onPressed: () async {
              await targetDevice?.disconnect();
              setState(() {
                targetDevice = null;
                tempData = "--";
                humidityData = "--";
                _startScanning();
              });
            }, 
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pico 2W Monitor")),
      body: isConnecting 
          ? _buildConnectingScreen()     // Phase 2
          : targetDevice == null 
              ? _buildScanningScreen()   // Phase 1
              : _buildDataScreen(),      // Phase 3
    );
  }
}