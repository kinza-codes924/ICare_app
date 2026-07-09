import 'package:flutter/material.dart';

class StructuredResultForm extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onResultsSubmit;
  final List<Map<String, dynamic>>? initialResults;

  const StructuredResultForm({
    super.key,
    required this.onResultsSubmit,
    this.initialResults,
  });

  @override
  State<StructuredResultForm> createState() => _StructuredResultFormState();
}

class _StructuredResultFormState extends State<StructuredResultForm> {
  final List<Map<String, dynamic>> _results = [];
  final _formKey = GlobalKey<FormState>();

  // Common test parameters with reference ranges
  static const Map<String, Map<String, dynamic>> commonTests = {
    'Glucose (Fasting)': {'unit': 'mg/dL', 'min': 70.0, 'max': 100.0},
    'Glucose (Postprandial)': {'unit': 'mg/dL', 'min': 70.0, 'max': 140.0},
    'HbA1c': {'unit': '%', 'min': 4.0, 'max': 5.6},
    'Total Cholesterol': {'unit': 'mg/dL', 'min': 0, 'max': 200.0},
    'HDL Cholesterol': {'unit': 'mg/dL', 'min': 40.0, 'max': 60.0},
    'LDL Cholesterol': {'unit': 'mg/dL', 'min': 0, 'max': 100.0},
    'Triglycerides': {'unit': 'mg/dL', 'min': 0, 'max': 150.0},
    'Hemoglobin': {'unit': 'g/dL', 'min': 12.0, 'max': 17.5},
    'White Blood Cells': {'unit': 'cells/µL', 'min': 4500, 'max': 11000},
    'Platelets': {'unit': 'cells/µL', 'min': 150000, 'max': 450000},
    'Creatinine': {'unit': 'mg/dL', 'min': 0.6, 'max': 1.2},
    'Urea': {'unit': 'mg/dL', 'min': 15.0, 'max': 45.0},
    'Uric Acid': {'unit': 'mg/dL', 'min': 3.5, 'max': 7.2},
    'TSH': {'unit': 'mIU/L', 'min': 0.4, 'max': 4.0},
    'Vitamin D': {'unit': 'ng/mL', 'min': 30.0, 'max': 100.0},
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialResults != null && widget.initialResults!.isNotEmpty) {
      _results.addAll(widget.initialResults!);
    } else {
      _addNewResult();
    }
  }

  void _addNewResult() {
    setState(() {
      _results.add({
        'testParameter': '',
        'value': '',
        'unit': '',
        'referenceRange': {'min': null, 'max': null},
      });
    });
  }

  void _removeResult(int index) {
    if (_results.length > 1) {
      setState(() {
        _results.removeAt(index);
      });
    }
  }

  void _onTestParameterSelected(int index, String testName) {
    final testInfo = commonTests[testName];
    if (testInfo != null) {
      setState(() {
        _results[index]['testParameter'] = testName;
        _results[index]['unit'] = testInfo['unit'];
        _results[index]['referenceRange'] = {
          'min': testInfo['min'],
          'max': testInfo['max'],
        };
      });
    }
  }

  bool _validateResults() {
    for (var result in _results) {
      if (result['testParameter'].toString().isEmpty ||
          result['value'].toString().isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _submitResults() {
    if (!_validateResults()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all test parameters and values'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onResultsSubmit(_results);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Enter Test Results',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _addNewResult,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add Parameter',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                return _buildResultCard(index);
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _submitResults,
                  icon: const Icon(Icons.check),
                  label: const Text('Submit Results'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(int index) {
    final result = _results[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Parameter #${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (_results.length > 1)
                  IconButton(
                    onPressed: () => _removeResult(index),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Test Parameter Dropdown
            DropdownButtonFormField<String>(
              initialValue: result['testParameter'].toString().isEmpty
                  ? null
                  : result['testParameter'],
              decoration: const InputDecoration(
                labelText: 'Test Parameter',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: commonTests.keys.map((testName) {
                return DropdownMenuItem(value: testName, child: Text(testName));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _onTestParameterSelected(index, value);
                }
              },
            ),
            const SizedBox(height: 12),

            // Value Input
            TextFormField(
              initialValue: result['value'],
              decoration: InputDecoration(
                labelText: 'Value',
                suffixText: result['unit']?.toString().isNotEmpty == true
                    ? result['unit']
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) {
                setState(() {
                  _results[index]['value'] = value;
                });
              },
            ),
            const SizedBox(height: 12),

            // Reference Range Display
            if (result['referenceRange'] != null &&
                (result['referenceRange']['min'] != null ||
                    result['referenceRange']['max'] != null))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Normal Range: ${_formatRange(result['referenceRange'])} ${result['unit'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatRange(Map<String, dynamic> range) {
    final min = range['min'];
    final max = range['max'];

    if (min != null && max != null) {
      return '$min - $max';
    } else if (min != null) {
      return '> $min';
    } else if (max != null) {
      return '< $max';
    }
    return 'N/A';
  }
}
