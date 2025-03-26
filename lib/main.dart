import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(ShelfManagementApp());
}

class ShelfManagementApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shelf Management',
      home: ShelfDashboard(),
    );
  }
}

class ShelfDashboard extends StatefulWidget {
  @override
  _ShelfDashboardState createState() => _ShelfDashboardState();
}

class _ShelfDashboardState extends State<ShelfDashboard> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _screens = [
    InventoryScreen(),
    AlertScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 280,
            color: Colors.purple.shade200,
            child: Column(
              children: [
                const SizedBox(height: 50),
                const Text(
                  'Shelf Manager',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),
                _buildSidebarButton(Icons.inventory, 'Inventory', 0),
                _buildSidebarButton(Icons.warning, 'Alerts', 1),
                _buildSidebarButton(Icons.bar_chart, 'Reports', 2),
                _buildSidebarButton(Icons.settings, 'Settings', 3),
              ],
            ),
          ),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildSidebarButton(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 15),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                          📦 INVENTORY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Item> items = [];

  @override
  void initState() {
    super.initState();
    fetchInventoryItems();
  }

  // Example GET to your local or remote API
  Future<void> fetchInventoryItems() async {
    final response = await http.get(Uri.parse('http://localhost:8080/api/inventory/items'));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body) as List<dynamic>;
      setState(() {
        items = jsonResponse.map((item) => Item.fromJson(item)).toList();
      });
    } else {
      throw Exception('Failed to load inventory items');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //                 SEND "EMPTY" OR "REFILL" TO THE M5STACK
  // ─────────────────────────────────────────────────────────────────────────

  // Called when item hits 0 → beep + red LED
  Future<void> _notifyM5StackEmpty(String itemName) async {
    final String m5stackIp = "192.168.0.175"; // Adjust to your M5 IP
    final int m5stackPort = 8080;             // Adjust if needed
    final String url = "http://$m5stackIp:$m5stackPort/notifyEmpty";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": "$itemName is out of stock!"}),
      );
      if (response.statusCode == 200) {
        print("Notification (EMPTY) sent to M5Stack.");
      } else {
        print("Failed to send empty notification. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error sending empty notification: $e");
    }
  }

  // Called when user refills item → stop beep, turn off LED
  Future<void> _notifyM5StackRefill(String itemName) async {
    final String m5stackIp = "192.168.0.175"; 
    final int m5stackPort = 8080; 
    final String url = "http://$m5stackIp:$m5stackPort/notifyRefill";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": "$itemName is refilled!"}),
      );
      if (response.statusCode == 200) {
        print("Notification (REFILL) sent to M5Stack.");
      } else {
        print("Failed to send refill notification. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error sending refill notification: $e");
    }
  }

  // Decrement item quantity
  void _removeItem(int index) {
    setState(() {
      if (items[index].quantity > 0) {
        items[index].quantity -= 1;

        // If quantity just became 0, notify M5Stack to beep + red LED
        if (items[index].quantity == 0) {
          _notifyM5StackEmpty(items[index].name);
        }
      }
    });
  }

  // Increment item quantity
  void _addItem(int index) {
    setState(() {
      final wasZeroBefore = (items[index].quantity == 0);
      items[index].quantity += 1;

      // If it was 0 before, we've "refilled" → notify M5Stack to stop beep
      if (wasZeroBefore) {
        _notifyM5StackRefill(items[index].name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Handy to refresh from your API
      floatingActionButton: FloatingActionButton(
        onPressed: fetchInventoryItems,
        child: const Icon(Icons.refresh),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      items[index].name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '€${items[index].price.toStringAsFixed(2)} per unit',
                      style: const TextStyle(color: Colors.green, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Qty: ${items[index].quantity}',
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                    ),
                    if (items[index].quantity == 0) BlinkingText(),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _removeItem(index),
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.purple, size: 24),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _addItem(index),
                          icon: const Icon(Icons.add_circle_outline, color: Colors.purple, size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                         🔴 BLINKING "REFILL" ALERT
// ─────────────────────────────────────────────────────────────────────────────
class BlinkingText extends StatefulWidget {
  @override
  _BlinkingTextState createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this)
      ..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Text(
        'REFILL',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                             📦 ITEM MODEL
// ─────────────────────────────────────────────────────────────────────────────
class Item {
  final String name;
  int quantity;
  final double price;

  Item({required this.name, required this.quantity, required this.price});

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'],
      quantity: json['quantity'],
      price: json['price'].toDouble(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                       PLACEHOLDER SCREENS
// ─────────────────────────────────────────────────────────────────────────────
class AlertScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('Alerts Screen'));
}

class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('Reports Screen'));
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(child: Text('Settings Screen'));
}
