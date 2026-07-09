import 'package:flutter/material.dart';
import '../services/lab_supply_service.dart';

class LabSuppliesManagement extends StatefulWidget {
  const LabSuppliesManagement({super.key});

  @override
  State<LabSuppliesManagement> createState() => _LabSuppliesManagementState();
}

class _LabSuppliesManagementState extends State<LabSuppliesManagement> {
  List<dynamic> supplies = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadSupplies();
  }

  Future<void> loadSupplies() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await LabSupplyService.getSupplies();
      setState(() {
        supplies = response['supplies'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void showAddSupplyDialog() {
    final formKey = GlobalKey<FormState>();
    String itemName = '';
    String category = 'Reagent';
    int currentStock = 0;
    int minStockLevel = 10;
    String unit = 'units';
    String? supplier;
    String? notes;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Supply Item'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Item Name'),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  onSaved: (v) => itemName = v!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['Reagent', 'Equipment', 'Consumable', 'Other']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => category = v!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Current Stock'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  onSaved: (v) => currentStock = int.parse(v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Min Stock Level',
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: '10',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  onSaved: (v) => minStockLevel = int.parse(v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Unit'),
                  initialValue: 'units',
                  onSaved: (v) => unit = v!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Supplier (Optional)',
                  ),
                  onSaved: (v) => supplier = v?.isEmpty ?? true ? null : v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                  ),
                  maxLines: 2,
                  onSaved: (v) => notes = v?.isEmpty ?? true ? null : v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context);

                try {
                  await LabSupplyService.addSupply(
                    itemName: itemName,
                    category: category,
                    currentStock: currentStock,
                    minStockLevel: minStockLevel,
                    unit: unit,
                    supplier: supplier,
                    notes: notes,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Supply added successfully'),
                      ),
                    );
                    loadSupplies();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void showUpdateStockDialog(dynamic supply) {
    final formKey = GlobalKey<FormState>();
    int amount = 0;
    String action = 'add';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock: ${supply['itemName']}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Stock: ${supply['currentStock']} ${supply['unit']}',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: action,
                decoration: const InputDecoration(labelText: 'Action'),
                items: [
                  const DropdownMenuItem(
                    value: 'add',
                    child: Text('Add Stock'),
                  ),
                  const DropdownMenuItem(
                    value: 'subtract',
                    child: Text('Use Stock'),
                  ),
                  const DropdownMenuItem(
                    value: 'set',
                    child: Text('Set Stock'),
                  ),
                ],
                onChanged: (v) => action = v!,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                onSaved: (v) => amount = int.parse(v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context);

                try {
                  await LabSupplyService.updateStock(
                    supplyId: supply['_id'],
                    currentStock: amount,
                    action: action,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Stock updated successfully'),
                      ),
                    );
                    loadSupplies();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Supplies Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadSupplies),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text('Error: $error'))
          : supplies.isEmpty
          ? const Center(child: Text('No supplies found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: supplies.length,
              itemBuilder: (context, index) {
                final supply = supplies[index];
                final isLowStock =
                    supply['currentStock'] <= supply['minStockLevel'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isLowStock ? Colors.red.shade50 : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isLowStock ? Colors.red : Colors.blue,
                      child: Icon(
                        _getCategoryIcon(supply['category']),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      supply['itemName'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category: ${supply['category']}'),
                        Text(
                          'Stock: ${supply['currentStock']} ${supply['unit']}',
                          style: TextStyle(
                            color: isLowStock ? Colors.red : Colors.black87,
                            fontWeight: isLowStock
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Text(
                          'Min Level: ${supply['minStockLevel']} ${supply['unit']}',
                        ),
                        if (supply['supplier'] != null)
                          Text('Supplier: ${supply['supplier']}'),
                        if (isLowStock)
                          const Text(
                            '⚠️ LOW STOCK ALERT',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'update',
                          child: Text('Update Stock'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'update') {
                          showUpdateStockDialog(supply);
                        } else if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: Text('Delete ${supply['itemName']}?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            try {
                              await LabSupplyService.deleteSupply(
                                supply['_id'],
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Supply deleted'),
                                  ),
                                );
                                loadSupplies();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: const Text('Something went wrong. Please try again.')),
                                );
                              }
                            }
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddSupplyDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Reagent':
        return Icons.science;
      case 'Equipment':
        return Icons.medical_services;
      case 'Consumable':
        return Icons.inventory;
      default:
        return Icons.category;
    }
  }
}
