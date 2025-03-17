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
                SizedBox(height: 50),
                Text(
                  'Shelf Manager',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 20),
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
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            SizedBox(width: 15),
            Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// Inventory Screen
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

  Future<void> fetchInventoryItems() async {
    final response = await http.get(Uri.parse('http://localhost:8080/api/inventory/items'));

    if (response.statusCode == 200) {
      List<dynamic> jsonResponse = json.decode(response.body);
      setState(() {
        items = jsonResponse.map((item) => Item.fromJson(item)).toList();
      });
    } else {
      throw Exception('Failed to load inventory items');
    }
  }

  void _removeItem(int index) {
    setState(() {
      if (items[index].quantity > 0) {
        items[index].quantity -= 1;
      }
    });
  }

  void _addItem(String name, int quantity, double price) {
    setState(() {
      items.add(Item(name: name, quantity: quantity, price: price));
    });
  }

  void _showAddItemDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController quantityController = TextEditingController();
    TextEditingController priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add New Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Item Name"),
              ),
              TextField(
                controller: quantityController,
                decoration: InputDecoration(labelText: "Quantity"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: "Price per unit (€)"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    quantityController.text.isNotEmpty &&
                    priceController.text.isNotEmpty) {
                  _addItem(
                    nameController.text,
                    int.tryParse(quantityController.text) ?? 0,
                    double.tryParse(priceController.text) ?? 0.0,
                  );
                  Navigator.pop(context);
                }
              },
              child: Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '€${items[index].price.toStringAsFixed(2)} per unit',
                      style: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Qty: ${items[index].quantity}',
                      style: TextStyle(color: Colors.black, fontSize: 14),
                    ),
                    if (items[index].quantity == 0)
                      BlinkingText(),
                    SizedBox(height: 6),
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: Icon(Icons.remove_circle_outline, color: Colors.purple, size: 24),
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

// Blinking Refill Text
class BlinkingText extends StatefulWidget {
  @override
  _BlinkingTextState createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(milliseconds: 500), vsync: this)
      ..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Text(
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

// Item Model
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

// Placeholder Screens
class AlertScreen extends StatelessWidget { Widget build(BuildContext context) => Center(child: Text('Alerts Screen')); }
class ReportsScreen extends StatelessWidget { Widget build(BuildContext context) => Center(child: Text('Reports Screen')); }
class SettingsScreen extends StatelessWidget { Widget build(BuildContext context) => Center(child: Text('Settings Screen')); }
