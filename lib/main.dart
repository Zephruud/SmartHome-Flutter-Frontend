import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(ShelfManagementApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────────────────────────────────────
class ShelfManagementApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf Management',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: ShelfDashboard(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN DASHBOARD WITH SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
class ShelfDashboard extends StatefulWidget {
  @override
  _ShelfDashboardState createState() => _ShelfDashboardState();
}

class _ShelfDashboardState extends State<ShelfDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    InventoryScreen(),
    Center(child: Text("Alerts")),  // you can later replace this
    ReportsScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            color: Theme.of(context).primaryColor,
            child: Column(
              children: [
                const SizedBox(height: 50),
                const Text(
                  'Shelf Manager',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),
                _buildSidebarButton(Icons.inventory, 'Inventory', 0),
                _buildSidebarButton(Icons.warning,   'Alerts',    1),
                _buildSidebarButton(Icons.bar_chart, 'Reports',   2),
                _buildSidebarButton(Icons.settings,  'Settings',  3),
              ],
            ),
          ),
          // Main content
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
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
class Item {
  final int? id;
  final String name;
  int quantity;
  final double price;

  Item({this.id, required this.name, required this.quantity, required this.price});

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'],
        name: json['name'],
        quantity: json['quantity'],
        price: (json['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// INVENTORY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Item> items = [];
  String searchQuery = "";
  String sortOption   = 'Name';

  @override
  void initState() {
    super.initState();
    fetchInventoryItems();
  }

  Future<void> fetchInventoryItems() async {
    final response = await http.get(Uri.parse('http://localhost:8080/api/inventory/items'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() => items = data.map((e) => Item.fromJson(e)).toList());
    } else {
      throw Exception('Failed to load items');
    }
  }

  Future<void> addNewItem(String name, int qty, double price) async {
    final newItem = Item(name: name, quantity: qty, price: price);
    final resp = await http.post(
      Uri.parse('http://localhost:8080/api/inventory/items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(newItem.toJson()),
    );
    if (resp.statusCode == 200) fetchInventoryItems();
  }

  Future<void> updateItem(int id, String name, int qty, double price) async {
    final updated = Item(id: id, name: name, quantity: qty, price: price);
    final resp = await http.put(
      Uri.parse('http://localhost:8080/api/inventory/items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updated.toJson()),
    );
    if (resp.statusCode == 200) fetchInventoryItems();
  }

  Future<void> deleteItem(int id) async {
    final resp = await http.delete(
      Uri.parse('http://localhost:8080/api/inventory/items/$id'),
    );
    if (resp.statusCode == 200) fetchInventoryItems();
  }

  List<Item> _sortedFiltered() {
    final filtered = items
        .where((it) => it.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
    switch (sortOption) {
      case 'Quantity':
        filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'Price':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Name':
      default:
        filtered.sort((a, b) => a.name.compareTo(b.name));
    }
    return filtered;
  }

  Widget _itemDialog({Item? item}) {
    final nameCtl  = TextEditingController(text: item?.name ?? "");
    final qtyCtl   = TextEditingController(text: item?.quantity.toString() ?? "");
    final priceCtl = TextEditingController(text: item?.price.toString() ?? "");
    return AlertDialog(
      title: Text(item == null ? 'Add Item' : 'Edit Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtl,  decoration: InputDecoration(labelText: 'Name')),
          TextField(controller: qtyCtl,   decoration: InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
          TextField(controller: priceCtl, decoration: InputDecoration(labelText: 'Price'),    keyboardType: TextInputType.number),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final name  = nameCtl.text.trim();
            final qty   = int.tryParse(qtyCtl.text) ?? 0;
            final price = double.tryParse(priceCtl.text) ?? 0.0;
            if (name.isNotEmpty) {
              if (item == null) addNewItem(name, qty, price);
              else updateItem(item.id!, name, qty, price);
              Navigator.pop(context);
            }
          },
          child: Text(item == null ? 'Add' : 'Save'),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _sortedFiltered();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(hintText: 'Search…'),
                onChanged: (v) => setState(() => searchQuery = v),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: sortOption,
              icon: Icon(Icons.sort, color: Colors.white),
              dropdownColor: Colors.white,
              items: ['Name', 'Quantity', 'Price']
                  .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                  .toList(),
              onChanged: (v) => setState(() => sortOption = v!),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple,
        child: Icon(Icons.add),
        onPressed: () => showDialog(context: context, builder: (_) => _itemDialog()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (ctx, cons) {
            final cross = cons.maxWidth < 600
                ? 1
                : cons.maxWidth < 900
                    ? 2
                    : 3;
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final it = list[i];
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(it.name,    style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 5),
                        Text('€${it.price.toStringAsFixed(2)}', style: TextStyle(color: Colors.green)),
                        const SizedBox(height: 5),
                        Text('Qty: ${it.quantity}', style: Theme.of(context).textTheme.bodyMedium),
                        if (it.quantity == 0) BlinkingText(),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline, color: Colors.purple),
                              onPressed: it.quantity > 0
                                  ? () {
                                      setState(() {
                                        it.quantity--;
                                        updateItem(it.id!, it.name, it.quantity, it.price);
                                      });
                                    }
                                  : null,
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline, color: Colors.purple),
                              onPressed: () {
                                setState(() {
                                  it.quantity++;
                                  updateItem(it.id!, it.name, it.quantity, it.price);
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteItem(it.id!),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => _itemDialog(item: it),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh, color: Colors.blue),
                              tooltip: 'Reload all',
                              onPressed: fetchInventoryItems,
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

// ─────────────────────────────────────────────────────────────────────────────
// REPORTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<Item>> _futureItems;

  @override
  void initState() {
    super.initState();
    _futureItems = fetchItemsForReport();
  }

  Future<List<Item>> fetchItemsForReport() async {
    final resp = await http.get(Uri.parse('http://localhost:8080/api/inventory/items'));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as List<dynamic>;
      return data.map((e) => Item.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load report items');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Report'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() => _futureItems = fetchItemsForReport()),
          )
        ],
      ),
      body: FutureBuilder<List<Item>>(
        future: _futureItems,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (snap.hasError)
            return Center(child: Text('Error: ${snap.error}'));

          final list = snap.data!;
          if (list.isEmpty)
            return Center(child: Text('No items in inventory.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (ctx, i) {
              final it = list[i];
              return ListTile(
                title: Text(it.name, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('€${it.price.toStringAsFixed(2)} • Qty: ${it.quantity}'),
                trailing: it.quantity == 0 ? Icon(Icons.error_outline, color: Colors.red) : null,
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Mosquitto Broker IP: 192.168.0.191'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLINKING REFILL WARNING
// ─────────────────────────────────────────────────────────────────────────────
class BlinkingText extends StatefulWidget {
  @override
  _BlinkingTextState createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<BlinkingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
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
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
