import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PatientAddressesScreen extends StatefulWidget {
  const PatientAddressesScreen({super.key});

  @override
  State<PatientAddressesScreen> createState() => _PatientAddressesScreenState();
}

class _PatientAddressesScreenState extends State<PatientAddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('patient_addresses') ?? '[]';
    final List list = jsonDecode(raw);
    setState(() {
      _addresses = list.cast<Map<String, dynamic>>();
    });
  }

  Future<void> _saveAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('patient_addresses', jsonEncode(_addresses));
  }

  void _addAddress() {
    _showAddressDialog();
  }

  void _editAddress(int index) {
    _showAddressDialog(index: index);
  }

  void _deleteAddress(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _addresses.removeAt(index));
              _saveAddresses();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddressDialog({int? index}) {
    final titleController = TextEditingController(
      text: index != null ? _addresses[index]['title'] ?? '' : '',
    );
    final addressController = TextEditingController(
      text: index != null ? _addresses[index]['address'] ?? '' : '',
    );
    String selectedType = index != null ? (_addresses[index]['type'] ?? 'home') : 'home';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            index != null ? 'Edit Address' : 'Add New Address',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type selector
                const Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _typeChip('home', 'Home', Icons.home_rounded, selectedType, (t) => setDialogState(() => selectedType = t)),
                    const SizedBox(width: 8),
                    _typeChip('work', 'Work', Icons.work_rounded, selectedType, (t) => setDialogState(() => selectedType = t)),
                    const SizedBox(width: 8),
                    _typeChip('other', 'Other', Icons.location_on_rounded, selectedType, (t) => setDialogState(() => selectedType = t)),
                  ],
                ),
                const SizedBox(height: 16),
                // Label
                const Text('Label', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Home, Office, Parents',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Address
                const Text('Full Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                TextField(
                  controller: addressController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Street, Area, City',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final addr = addressController.text.trim();
                if (addr.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an address')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() {
                  final entry = {
                    'title': titleController.text.trim().isEmpty
                        ? (selectedType == 'home' ? 'Home' : selectedType == 'work' ? 'Work' : 'Other')
                        : titleController.text.trim(),
                    'address': addr,
                    'type': selectedType,
                    'isDefault': index != null ? (_addresses[index]['isDefault'] ?? false) : _addresses.isEmpty,
                  };
                  if (index != null) {
                    _addresses[index] = entry;
                  } else {
                    _addresses.add(entry);
                  }
                });
                _saveAddresses();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(index != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label, IconData icon, String selected, Function(String) onTap) {
    final isSelected = selected == type;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryColor : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }

  void _setDefault(int index) {
    setState(() {
      for (int i = 0; i < _addresses.length; i++) {
        _addresses[i] = Map<String, dynamic>.from(_addresses[i])
          ..['isDefault'] = i == index;
      }
    });
    _saveAddresses();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_addresses[index]['title']} set as default address'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Your Addresses',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _addAddress,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _addresses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No addresses saved yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your home, office or other addresses',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addAddress,
                    icon: const Icon(Icons.add_location_rounded),
                    label: const Text('Add Address'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _addresses.length,
              itemBuilder: (ctx, i) => _buildAddressCard(_addresses[i], i),
            ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> addr, int index) {
    final isDefault = addr['isDefault'] == true;
    final type = addr['type'] ?? 'other';

    IconData typeIcon;
    Color typeColor;
    if (type == 'home') {
      typeIcon = Icons.home_rounded;
      typeColor = AppColors.primaryColor;
    } else if (type == 'work') {
      typeIcon = Icons.work_rounded;
      typeColor = const Color(0xFF8B5CF6);
    } else {
      typeIcon = Icons.location_on_rounded;
      typeColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? AppColors.primaryColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        addr['title'] ?? 'Address',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    addr['address'] ?? '',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!isDefault)
                        TextButton(
                          onPressed: () => _setDefault(index),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Set Default', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _editAddress(index),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: const Color(0xFF64748B),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _deleteAddress(index),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
