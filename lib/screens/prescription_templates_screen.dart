import 'package:flutter/material.dart';
import 'package:icare/services/efficiency_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class PrescriptionTemplatesScreen extends StatefulWidget {
  const PrescriptionTemplatesScreen({super.key});

  @override
  State<PrescriptionTemplatesScreen> createState() =>
      _PrescriptionTemplatesScreenState();
}

class _PrescriptionTemplatesScreenState
    extends State<PrescriptionTemplatesScreen> {
  final EfficiencyService _efficiencyService = EfficiencyService();
  bool _isLoading = true;
  List<dynamic> _templates = [];

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  Future<void> _fetchTemplates() async {
    setState(() => _isLoading = true);
    try {
      final templates = await _efficiencyService.getPrescriptionTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: const Text('Unable to load data. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Prescription Templates',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTemplateDialog(),
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Template',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
          ? _buildEmptyState()
          : _buildTemplatesList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No prescription templates yet.'));
  }

  Widget _buildTemplatesList() {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final template = _templates[index];
        final drugs = (template['drugs'] ?? []) as List<dynamic>;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    template['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmRemoveTemplate(
                      template['id'],
                      template['name'],
                    ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: drugs
                    .map(
                      (drug) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${drug['name']} (${drug['dosage']})',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddTemplateDialog() {
    final nameController = TextEditingController();
    final drugNameController = TextEditingController();
    final dosageController = TextEditingController();
    List<Map<String, String>> currentDrugs = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'New Template',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Template Name',
                    hintText: 'e.g. Standard Cold',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Add Drugs',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: drugNameController,
                  decoration: const InputDecoration(labelText: 'Drug Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(labelText: 'Dosage'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    if (drugNameController.text.isNotEmpty &&
                        dosageController.text.isNotEmpty) {
                      setDialogState(() {
                        currentDrugs.add({
                          'name': drugNameController.text,
                          'dosage': dosageController.text,
                        });
                        drugNameController.clear();
                        dosageController.clear();
                      });
                    }
                  },
                  child: const Text('Add to Template'),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: currentDrugs
                      .map(
                        (d) => Text(
                          '• ${d['name']} (${d['dosage']})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      )
                      .toList(),
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
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a template name')),
                  );
                  return;
                }
                if (currentDrugs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please add at least one drug')),
                  );
                  return;
                }
                final result = await _efficiencyService.createPrescriptionTemplate({
                  'name': nameController.text,
                  'drugs': currentDrugs,
                });
                if (!context.mounted) return;
                if (result['success'] == true) {
                  Navigator.pop(context);
                  _fetchTemplates();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Template saved successfully'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save: ${result['message'] ?? 'Unknown error'}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save Template'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveTemplate(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete the template "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _efficiencyService.deletePrescriptionTemplate(id);
              Navigator.pop(context);
              _fetchTemplates();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
