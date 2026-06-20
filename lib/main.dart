 import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ================== DATA MODELS ==================
class Device {
  final String id;
  final String name;
  final String type;
  bool isOn;
  final double? value;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.isOn,
    required this.value,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    final v = json['value'];
    return Device(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'OTHER').toString(),
      isOn: json['on'] ?? false,
      value: (v is num) ? v.toDouble() : null,
    );
  }
}

class Room {
  final String id;
  final String name;
  final List<Device> devices;

  Room({required this.id, required this.name, required this.devices});

  factory Room.fromJson(Map<String, dynamic> json) {
    final deviceList = (json['devices'] as List<dynamic>? ?? [])
        .map((d) => Device.fromJson(d as Map<String, dynamic>))
        .toList();

    return Room(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      devices: deviceList,
    );
  }
}

// ================== BACKEND ==================
const String backendBaseUrl =
    'https://smarthome-backend-production-2612.up.railway.app';

Future<List<Room>> fetchRooms() async {
  final url = '$backendBaseUrl/api/rooms';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    throw Exception('Failed to load rooms: ${response.statusCode}');
  }

  final data = json.decode(response.body) as List<dynamic>;
  return data.map((room) => Room.fromJson(room)).toList();
}

Future<Room> fetchRoomById(String roomId) async {
  final url = '$backendBaseUrl/api/rooms/$roomId';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    throw Exception('Failed to refresh room: ${response.statusCode}');
  }

  return Room.fromJson(json.decode(response.body));
}

Future<void> toggleDeviceOnBackend(
    Room room, Device device, bool newState) async {
  final url = '$backendBaseUrl/api/rooms/${room.id}/devices/${device.id}';
  final body = jsonEncode({'on': newState});

  final response = await http.patch(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: body,
  );

  if (response.statusCode != 200) {
    throw Exception(
        'Failed to toggle device: ${response.statusCode} ${response.body}');
  }
}

Future<void> addDeviceOnBackend(String roomId, String name, String type) async {
  final url = '$backendBaseUrl/api/rooms/$roomId/devices';

  final res = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'name': name, 'type': type}),
  );

  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Failed to add device: ${res.statusCode} ${res.body}');
  }
}

Future<void> deleteDeviceOnBackend(String roomId, String deviceId) async {
  final url = '$backendBaseUrl/api/rooms/$roomId/devices/$deviceId';

  final res = await http.delete(Uri.parse(url));

  if (res.statusCode != 200 && res.statusCode != 204) {
    throw Exception('Failed to delete device: ${res.statusCode} ${res.body}');
  }
}

// ================== SAVE ENERGY MODE ==================
Future<bool> fetchSaveEnergyMode() async {
  final url = '$backendBaseUrl/api/modes/save-energy';
  final res = await http.get(Uri.parse(url));

  if (res.statusCode != 200) {
    throw Exception('Failed to fetch save energy mode');
  }

  final data = json.decode(res.body) as Map<String, dynamic>;
  return data['enabled'] == true;
}

Future<bool> setSaveEnergyMode(bool enabled) async {
  final url = '$backendBaseUrl/api/modes/save-energy';

  final res = await http.put(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'enabled': enabled}),
  );

  if (res.statusCode != 200) {
    throw Exception('Failed to set save energy mode');
  }

  final data = json.decode(res.body) as Map<String, dynamic>;
  return data['enabled'] == true;
}

// ================== HELPERS ==================
String norm(String s) =>
    s.toLowerCase().replaceAll('_', '').replaceAll(' ', '');

String displayRoomName(String name) {
  if (name.toLowerCase().trim() == 'keller') {
    return 'Cellar';
  }
  return name;
}

bool isLight(Device d) => norm(d.type) == 'light';
bool isHeater(Device d) => norm(d.type) == 'heater';
bool isWindow(Device d) => norm(d.type) == 'window';
bool isDoorLock(Device d) => norm(d.type) == 'doorlock';

bool isTemperature(Device d) => norm(d.type) == 'temperature';
bool isHumidity(Device d) =>
    norm(d.type) == 'humidity' || norm(d.type) == 'humid';

bool isLivingRoomName(String name) =>
    name.toLowerCase().trim() == 'living room';

IconData getRoomIcon(String roomName) {
  switch (roomName.toLowerCase()) {
    case 'living room':
      return Icons.weekend;
    case 'kitchen':
      return Icons.restaurant;
    case 'bedroom':
      return Icons.bed;
    case 'bathroom':
      return Icons.bathtub;
    case 'cellar':
    case 'basement':
      return Icons.warehouse;
    case 'store room':
    case 'storeroom':
    case 'storage room':
      return Icons.inventory;
    default:
      return Icons.home;
  }
}

IconData getDeviceIcon(String type) {
  switch (norm(type)) {
    case 'light':
      return Icons.lightbulb;
    case 'heater':
      return Icons.fireplace;
    case 'doorlock':
      return Icons.lock;
    case 'temperature':
      return Icons.thermostat;
    case 'humidity':
    case 'humid':
      return Icons.water_drop;
    case 'window':
      return Icons.window;
    default:
      return Icons.devices_other;
  }
}

double? firstTemp(Room r) {
  for (final d in r.devices) {
    if (isTemperature(d) && d.value != null) return d.value;
  }
  return null;
}

double? firstHum(Room r) {
  for (final d in r.devices) {
    if (isHumidity(d) && d.value != null) return d.value;
  }
  return null;
}

int lightsOn(Room r) =>
    r.devices.where((d) => isLight(d) && d.isOn).length;

int heatersOn(Room r) =>
    r.devices.where((d) => isHeater(d) && d.isOn).length;

int windowsOpen(Room r) =>
    r.devices.where((d) => isWindow(d) && d.isOn).length;

Device? firstWindow(Room r) {
  for (final d in r.devices) {
    if (isWindow(d)) return d;
  }
  return null;
}

Color glowColor(Device device, Animation<double> heaterAnim) {
  final t = norm(device.type);

  if (t == 'light' && device.isOn) {
    return Colors.yellow.withOpacity(0.80);
  }

  if (t == 'heater' && device.isOn) {
    return Color.lerp(
      Colors.redAccent,
      Colors.orange,
      heaterAnim.value,
    )!;
  }

  if (t == 'window' && device.isOn) {
    return Colors.lightBlueAccent.withOpacity(0.50);
  }

  if (t == 'temperature' || t == 'humidity' || t == 'humid') {
    return Colors.blueGrey.shade100;
  }

  return Colors.grey.shade200;
}

String formatTime(DateTime dt) {
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}

// ================== MAIN APP ==================
void main() => runApp(SmartHomeApp());

class SmartHomeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Arial'),
      home: RoomListScreen(),
    );
  }
}

// ================== ROOM LIST SCREEN ==================
class RoomListScreen extends StatefulWidget {
  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  late Future<List<Room>> _futureRooms;

  bool _saveEnergyEnabled = false;
  bool _loadingEnergy = false;

  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _futureRooms = fetchRooms();

    fetchSaveEnergyMode().then((v) {
      if (mounted) setState(() => _saveEnergyEnabled = v);
    }).catchError((_) {});
  }

  Future<void> _refresh() async {
    setState(() {
      _futureRooms = fetchRooms();
      _lastUpdated = DateTime.now();
    });

    await _futureRooms;

    try {
      final v = await fetchSaveEnergyMode();
      if (mounted) setState(() => _saveEnergyEnabled = v);
    } catch (_) {}
  }

  Future<void> _toggleSaveEnergy(bool v) async {
    setState(() => _loadingEnergy = true);

    try {
      final newVal = await setSaveEnergyMode(v);
      if (mounted) setState(() => _saveEnergyEnabled = newVal);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save Energy failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingEnergy = false);
    }
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeOverviewCard(List<Room> rooms) {
    final totalLightsOn = rooms.fold(0, (acc, r) => acc + lightsOn(r));
    final totalHeatersOn = rooms.fold(0, (acc, r) => acc + heatersOn(r));
    final totalWindowsOpen = rooms.fold(0, (acc, r) => acc + windowsOpen(r));

    final temps = rooms.map(firstTemp).whereType<double>().toList();
    final hums = rooms.map(firstHum).whereType<double>().toList();

    final avgTemp =
        temps.isEmpty ? null : temps.reduce((a, b) => a + b) / temps.length;

    final avgHum =
        hums.isEmpty ? null : hums.reduce((a, b) => a + b) / hums.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_customize, color: Colors.black87),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Home Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Updated ${formatTime(_lastUpdated)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('$totalLightsOn lights ON', Icons.lightbulb_outline),
              _chip('$totalHeatersOn heaters ON', Icons.fireplace),
              _chip('$totalWindowsOpen windows OPEN', Icons.window),
              if (avgTemp != null)
                _chip('${avgTemp.toStringAsFixed(1)}°C avg',
                    Icons.thermostat),
              if (avgHum != null)
                _chip('${avgHum.toStringAsFixed(0)}% avg',
                    Icons.water_drop),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.eco,
                color: _saveEnergyEnabled ? Colors.green : Colors.black45,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Save Energy is ${_saveEnergyEnabled ? "ON" : "OFF"}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text('Smart Home Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.green),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Save Energy Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_loadingEnergy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: _saveEnergyEnabled,
                    onChanged: _toggleSaveEnergy,
                  ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Room>>(
        future: _futureRooms,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed: ${snapshot.error}'));
          }

          final rooms = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: rooms.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _homeOverviewCard(rooms);

                final room = rooms[index - 1];

                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 4,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: Icon(
                      getRoomIcon(displayRoomName(room.name)),
                      color: Colors.blueAccent,
                      size: 30,
                    ),
                    title: Text(
                      displayRoomName(room.name),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.black54,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomDetailScreen(
                          room: room,
                          saveEnergyEnabled: _saveEnergyEnabled,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ================== ROOM DETAIL SCREEN ==================
class RoomDetailScreen extends StatefulWidget {
  final Room room;
  final bool saveEnergyEnabled;

  const RoomDetailScreen({
    Key? key,
    required this.room,
    required this.saveEnergyEnabled,
  }) : super(key: key);

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late Room _room;
  Timer? _pollTimer;
  late AnimationController _heaterAnimation;

  bool get _isLivingRoom => isLivingRoomName(_room.name);

  @override
  void initState() {
    super.initState();
    _room = widget.room;

    _heaterAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final fresh = await fetchRoomById(_room.id);
        if (mounted) setState(() => _room = fresh);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _heaterAnimation.dispose();
    super.dispose();
  }

  Future<void> _refreshRoom() async {
    final fresh = await fetchRoomById(_room.id);
    setState(() => _room = fresh);
  }

  Future<void> _handleToggle(Device device, bool newValue) async {
    if (isTemperature(device) || isHumidity(device)) return;
    if (_isLivingRoom && widget.saveEnergyEnabled && isHeater(device)) return;

    final oldValue = device.isOn;
    setState(() => device.isOn = newValue);

    try {
      await toggleDeviceOnBackend(_room, device, newValue);
      await _refreshRoom();
    } catch (e) {
      setState(() => device.isOn = oldValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle device: $e')),
      );
    }
  }

  bool get _windowOpen {
    final w = firstWindow(_room);
    return w != null && w.isOn;
  }

  bool get _heaterLocked => _isLivingRoom && widget.saveEnergyEnabled;

  bool get _showWindowRuleBanner => _heaterLocked && _windowOpen;

  Future<void> _showAddDeviceDialog() async {
    final nameCtrl = TextEditingController();
    String selectedType = 'LIGHT';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Device name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: const [
                DropdownMenuItem(value: 'LIGHT', child: Text('LIGHT')),
                DropdownMenuItem(value: 'HEATER', child: Text('HEATER')),
                DropdownMenuItem(value: 'WINDOW', child: Text('WINDOW')),
                DropdownMenuItem(value: 'DOOR_LOCK', child: Text('DOOR_LOCK')),
                DropdownMenuItem(
                    value: 'TEMPERATURE', child: Text('TEMPERATURE')),
                DropdownMenuItem(value: 'HUMIDITY', child: Text('HUMIDITY')),
              ],
              onChanged: (v) => selectedType = v ?? selectedType,
              decoration: const InputDecoration(labelText: 'Type'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    try {
      await addDeviceOnBackend(_room.id, name, selectedType);
      await _refreshRoom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add device failed: $e')),
      );
    }
  }

  Future<void> _confirmDelete(Device d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete device?'),
        content: Text('Delete "${d.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await deleteDeviceOnBackend(_room.id, d.id);
      await _refreshRoom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text(displayRoomName(_room.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDeviceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRoom,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _heaterAnimation,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _refreshRoom,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_showWindowRuleBanner)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.40),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Window open → heater disabled',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ..._room.devices.map((device) {
                  final cardColor = glowColor(device, _heaterAnimation);

                  final isTemp = isTemperature(device);
                  final isHum = isHumidity(device);
                  final isSensor = isTemp || isHum;

                  final heaterAutoLocked =
                      _heaterLocked && isHeater(device);

                  final subtitle = () {
                    if (isTemp) {
                      return device.value == null
                          ? '— °C'
                          : '${device.value!.toStringAsFixed(1)} °C';
                    }

                    if (isHum) {
                      return device.value == null
                          ? '— %'
                          : '${device.value!.toStringAsFixed(0)} %';
                    }

                    if (isHeater(device)) {
                      return heaterAutoLocked
                          ? 'Save Energy ON • Auto controlled'
                          : 'Manual heater control';
                    }

                    if (isWindow(device)) {
                      return device.isOn ? 'OPEN' : 'CLOSED';
                    }

                    if (isDoorLock(device)) {
                      return device.isOn ? 'LOCKED' : 'UNLOCKED';
                    }

                    return device.isOn ? 'ON' : 'OFF';
                  }();

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: (device.isOn && !isSensor)
                          ? [
                              BoxShadow(
                                color: cardColor.withOpacity(0.6),
                                blurRadius: 12,
                                spreadRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          getDeviceIcon(device.type),
                          size: 32,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSensor)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.black45,
                            ),
                            onPressed: () => _confirmDelete(device),
                            tooltip: 'Delete device',
                          )
                        else if (heaterAutoLocked)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock, color: Colors.black54),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.black45,
                                ),
                                onPressed: () => _confirmDelete(device),
                                tooltip: 'Delete device',
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: device.isOn,
                                onChanged: (value) =>
                                    _handleToggle(device, value),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.black45,
                                ),
                                onPressed: () => _confirmDelete(device),
                                tooltip: 'Delete device',
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}