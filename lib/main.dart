import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(ShelfManagementApp()); // Entry point of the app
}

// Root widget of the application
class ShelfManagementApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shelf Management',
      themeMode: ThemeMode.system, // Automatically use light/dark mode
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: ShelfDashboard(), // Start screen
    );
  }
}

// Main Dashboard with bottom navigation
class ShelfDashboard extends StatefulWidget {
  @override
  _ShelfDashboardState createState() => _ShelfDashboardState();
}

class _ShelfDashboardState extends State<ShelfDashboard> {
  int _selectedIndex = 0; // Current tab index

  final List<Widget> _screens = [
    InventoryScreen(), // Inventory tab
    Center(child: Text("Alerts")), // Placeholder
    Center(child: Text("Reports")), // Placeholder
    SettingsScreen(), // Settings tab
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Change tab
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar navigation
          Container(
            width: 260,
            color: Theme.of(context).primaryColor,
            child: Column(
              children: [
                const SizedBox(height: 50),
                Text(
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

  // Sidebar buttons
  Widget _buildSidebarButton(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 15),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

// Inventory item model
class Item {
  final int? id;
  final String name;
  int quantity;
  final double price;

  Item({this.id, required this.name, required this.quantity, required this.price});

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'],
      price: json['price'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }
}

// Inventory UI and logic
class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Item> items = [];
  String searchQuery = "";
  String sortOption = 'Name';

  @override
  void initState() {
    super.initState();
    fetchInventoryItems(); // Load data on startup
  }

  // Fetch items from backend
  Future<void> fetchInventoryItems() async {
    final response = await http.get(Uri.parse('http://localhost:8080/api/inventory/items'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body) as List<dynamic>;
      setState(() {
        items = jsonResponse.map((item) => Item.fromJson(item)).toList();
      });
    } else {
      throw Exception('Failed to load items');
    }
  }

  // Add item to backend
  Future<void> addNewItem(String name, int quantity, double price) async {
    final newItem = Item(name: name, quantity: quantity, price: price);
    final response = await http.post(
      Uri.parse('http://localhost:8080/api/inventory/items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(newItem.toJson()),
    );
    if (response.statusCode == 200) fetchInventoryItems();
  }

  // Update item in backend also essential for mqtt broker connection
  Future<void> updateItem(int id, String name, int quantity, double price) async {
    final updated = Item(id: id, name: name, quantity: quantity, price: price);
    final response = await http.put(
      Uri.parse('http://localhost:8080/api/inventory/items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updated.toJson()),
    );
    if (response.statusCode == 200) fetchInventoryItems();
  }

  // Delete item
  Future<void> deleteItem(int id) async {
    final response = await http.delete(Uri.parse('http://localhost:8080/api/inventory/items/$id'));
    if (response.statusCode == 200) fetchInventoryItems();
  }

  // Sort + filter items
  List<Item> _getSortedFilteredItems() {
    List<Item> filtered = items.where((item) => item.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
    if (sortOption == 'Name') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    } else if (sortOption == 'Quantity') {
      filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
    } else if (sortOption == 'Price') {
      filtered.sort((a, b) => b.price.compareTo(a.price));
    }
    return filtered;
  }

  // Dialog for add/edit
  Widget _buildAddOrEditItemDialog({Item? item}) {
    final nameController = TextEditingController(text: item?.name ?? "");
    final qtyController = TextEditingController(text: item?.quantity.toString() ?? "");
    final priceController = TextEditingController(text: item?.price.toString() ?? "");

    return AlertDialog(
      title: Text(item == null ? "Add New Item" : "Edit Item"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameController, decoration: InputDecoration(labelText: "Name")),
          TextField(controller: qtyController, decoration: InputDecoration(labelText: "Quantity"), keyboardType: TextInputType.number),
          TextField(controller: priceController, decoration: InputDecoration(labelText: "Price"), keyboardType: TextInputType.number),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            final name = nameController.text.trim();
            final qty = int.tryParse(qtyController.text) ?? 0;
            final price = double.tryParse(priceController.text) ?? 0.0;
            if (name.isNotEmpty) {
              if (item == null) {
                addNewItem(name, qty, price);
              } else {
                updateItem(item.id!, name, qty, price);
              }
              Navigator.pop(context);
            }
          },
          child: Text(item == null ? "Add" : "Save"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getSortedFilteredItems();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Search bar
            Expanded(
              child: TextField(
                decoration: InputDecoration(hintText: 'Search Item'),
                onChanged: (val) => setState(() => searchQuery = val),
              ),
            ),
            const SizedBox(width: 10),
            // Sort dropdown
            DropdownButton<String>(
              value: sortOption,
              dropdownColor: Colors.white,
              icon: Icon(Icons.sort, color: Colors.white),
              items: ['Name', 'Quantity', 'Price'].map((value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (val) => setState(() => sortOption = val!),
            ),
          ],
        ),
        backgroundColor: Colors.purple,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (_) => _buildAddOrEditItemDialog()),
        child: const Icon(Icons.add),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive layout
            int crossAxisCount = constraints.maxWidth < 600
                ? 1 // Mobile
                : constraints.maxWidth < 900
                    ? 2 // Tablet
                    : 3; // Desktop

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 5),
                        Text('€${item.price.toStringAsFixed(2)} per unit', style: TextStyle(color: Colors.green)),
                        const SizedBox(height: 5),
                        Text('Qty: ${item.quantity}', style: Theme.of(context).textTheme.bodyMedium),
                        if (item.quantity == 0) BlinkingText(), // REFILL alert
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (item.quantity > 0) {
                                    item.quantity--;
                                    updateItem(item.id!, item.name, item.quantity, item.price);
                                  }
                                });
                              },
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.purple),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  item.quantity++;
                                  updateItem(item.id!, item.name, item.quantity, item.price);
                                });
                              },
                              icon: const Icon(Icons.add_circle_outline, color: Colors.purple),
                            ),
                            IconButton(
                              onPressed: () => deleteItem(item.id!),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                            IconButton(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => _buildAddOrEditItemDialog(item: item),
                              ),
                              icon: const Icon(Icons.edit, color: Colors.orange),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// Settings screen
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Mosquitto Broker IP: 192.168.0.191'),
      ),
    );
  }
}

// Refill warning text that blinks
class BlinkingText extends StatefulWidget {
  @override
  _BlinkingTextState createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true); // Blink
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Text(
        'REFILL',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
