import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/models/course.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/clinical_service.dart';
import 'package:icare/services/icd_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SoapNotesRedesign extends StatefulWidget {
  final AppointmentDetail? appointment;

  const SoapNotesRedesign({super.key, this.appointment});

  @override
  State<SoapNotesRedesign> createState() => _SoapNotesRedesignState();
}

class _SoapNotesRedesignState extends State<SoapNotesRedesign> {
  final _formKey = GlobalKey<FormState>();
  final ClinicalService _clinicalService = ClinicalService();
  final CourseService _courseService = CourseService();

  final _subjectiveController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _assessmentController = TextEditingController();
  final _planController = TextEditingController();

  late stt.SpeechToText _speech;
  bool _isListening = false;

  List<Course> _availablePrograms = [];
  Course? _selectedProgram;
  bool _isLoading = true;
  bool _isFinalized = false;
  List<String> _attachments = [];
  List<dynamic> _addendums = [];
  String? _icdCode;
  final TextEditingController _icdSearchController = TextEditingController();
  List<Map<String, dynamic>> _icdResults = [];

  // Requirement 36.12: Smart Template Suggestions
  final Map<String, Map<String, String>> _templates = {
    'I10': {
      'subjective':
          'Patient reports occasional headaches and dizziness. No chest pain or shortness of breath.',
      'objective': 'BP: 150/95 mmHg. Heart rate regular. No peripheral edema.',
      'assessment': 'Essential Hypertension - Stage 1.',
      'plan':
          'Start Lisinopril 10mg daily. Dash diet recommended. Follow up in 2 weeks for BP check.',
    },
    'E11.9': {
      'subjective':
          'Patient monitoring blood glucose. Reports polyuria and increased thirst.',
      'objective':
          'Weight: 85kg. BMI: 29. Foot exam: normal sensation, pulses present.',
      'assessment': 'Type 2 Diabetes Mellitus - Controlled.',
      'plan':
          'Continue Metformin 500mg BID. HbA1c test ordered. Referral to diabetes educator.',
    },
    'J06.9': {
      'subjective': 'Sore throat, cough, and rhinorrhea for 3 days. No fever.',
      'objective':
          'T: 98.6F. Pharynx erythematous. Lungs clear to auscultation.',
      'assessment': 'Acute Upper Respiratory Infection (URI).',
      'plan':
          'Symptomatic treatment. Hydration. Saline nasal spray. Return if symptoms worsen.',
    },
  };

  void _applyTemplate(String code) {
    final template = _templates[code];
    if (template != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Apply Clinical Template?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Would you like to auto-fill the SOAP notes with the standard template for $code?',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _subjectiveController.text = template['subjective']!;
                  _objectiveController.text = template['objective']!;
                  _assessmentController.text = template['assessment']!;
                  _planController.text = template['plan']!;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Yes, Apply'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final programs = await _courseService.getHealthPrograms();
      setState(() => _availablePrograms = programs);

      if (widget.appointment != null) {
        final result = await _clinicalService.getSoapNotes(
          widget.appointment!.id,
        );
        if (result['success'] && result['notes'] != null) {
          final notes = result['notes'];
          setState(() {
            _subjectiveController.text = notes['subjective'] ?? '';
            _objectiveController.text = notes['objective'] ?? '';
            _assessmentController.text = notes['assessment'] ?? '';
            _planController.text = notes['plan'] ?? '';
            _icdCode = notes['icdCode'];
            _isFinalized = notes['isFinalized'] ?? false;
            _attachments = List<String>.from(notes['attachments'] ?? []);
            _addendums = List<dynamic>.from(notes['addendums'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading SOAP data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _searchIcd(String query) async {
    if (query.isEmpty || query.length < 2) {
      setState(() => _icdResults = []);
      return;
    }

    try {
      final results = await ICDService.searchICDCodes(query);
      setState(() {
        _icdResults = results
            .map((item) => {'code': item['code'], 'desc': item['description']})
            .toList();
      });
    } catch (e) {
      debugPrint('Error searching ICD codes: $e');
      setState(() => _icdResults = []);
    }
  }

  void _addAddendum() async {
    final TextEditingController addendumController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Signed Addendum'),
        content: TextField(
          controller: addendumController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter additional clinical information...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (addendumController.text.isEmpty) return;
              try {
                await _clinicalService.addAddendum(
                  widget.appointment!.id,
                  'soap',
                  addendumController.text,
                );
                Navigator.pop(ctx);
                _loadData();
              } catch (e) {
                debugPrint('Addendum error: $e');
              }
            },
            child: const Text('Sign & Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subjectiveController.dispose();
    _objectiveController.dispose();
    _assessmentController.dispose();
    _planController.dispose();
    super.dispose();
  }

  void _saveNotes({bool finalize = false}) async {
    if (widget.appointment == null) return;

    setState(() => _isLoading = true);
    try {
      await _clinicalService.saveSoapNotes(widget.appointment!.id, {
        'subjective': _subjectiveController.text,
        'objective': _objectiveController.text,
        'assessment': _assessmentController.text,
        'plan': _planController.text,
        'icdCode': _icdCode,
        'isFinalized': finalize,
        'attachments': _attachments,
      });

      if (_selectedProgram != null) {
        await _courseService.assignHealthProgram(
          widget.appointment!.patient?.id ?? '',
          _selectedProgram!.id,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalize ? 'SOAP Notes finalized' : 'SOAP Notes saved',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _listeningField = '';

  void _startListening(
    TextEditingController controller,
    String fieldName,
  ) async {
    if (_isListening && _listeningField == fieldName) {
      setState(() {
        _isListening = false;
        _listeningField = '';
      });
      _speech.stop();
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          setState(() {
            _isListening = false;
            _listeningField = '';
          });
        }
      },
      onError: (val) => debugPrint('onError: $val'),
    );

    if (available) {
      setState(() {
        _isListening = true;
        _listeningField = fieldName;
      });

      final String initialText = controller.text;

      _speech.listen(
        onResult: (val) {
          setState(() {
            if (val.recognizedWords.isNotEmpty) {
              controller.text = initialText.isEmpty
                  ? val.recognizedWords
                  : '$initialText ${val.recognizedWords}';
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            }
          });
        },
      );
    }
  }

  void _addAttachment() {
    setState(
      () =>
          _attachments.add('scan_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return isDesktop ? _buildWebView() : _buildMobileView();
  }

  Widget _buildMobileView() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'SOAP Notes',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isFinalized)
            IconButton(
              onPressed: _addAttachment,
              icon: const Icon(
                Icons.add_photo_alternate_rounded,
                color: AppColors.primaryColor,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isFinalized) _buildLockIndicator(),
              _buildSectionTitle('S - Subjective'),
              _buildTextField(
                _subjectiveController,
                'Symptoms & Complaints',
                4,
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('O - Objective'),
              _buildTextField(_objectiveController, 'Examination Findings', 4),
              const SizedBox(height: 20),
              _buildSectionTitle('A - Assessment'),
              _buildTextField(_assessmentController, 'Diagnosis', 4),
              const SizedBox(height: 20),
              _buildSectionTitle('Standardized Diagnosis (ICD-10)'),
              _buildIcdSelector(),
              const SizedBox(height: 20),
              _buildSectionTitle('P - Plan'),
              _buildTextField(_planController, 'Treatment Plan', 4),

              const SizedBox(height: 20),
              _buildSectionTitle('Health Program Assignment'),
              _buildProgramSelector(),

              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Attachments',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8,
                  children: _attachments
                      .map(
                        (a) => Chip(
                          label: Text(a, style: const TextStyle(fontSize: 10)),
                          onDeleted: _isFinalized
                              ? null
                              : () => setState(() => _attachments.remove(a)),
                        ),
                      )
                      .toList(),
                ),
              ],

              if (_isFinalized) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Signed Addendums',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addAddendum,
                      icon: const Icon(Icons.add_comment_rounded, size: 16),
                      label: const Text(
                        'Add Addendum',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_addendums.isEmpty)
                  const Text(
                    'No addendums added yet.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  )
                else
                  ..._addendums
                      .map(
                        (a) => _buildAddendumTile(
                          a['text'] ?? '',
                          a['createdAt']?.toString().substring(0, 16) ?? '',
                        ),
                      )
                      ,
              ],

              const SizedBox(height: 40),
              if (!_isFinalized) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _saveNotes(finalize: false),
                    child: const Text('Save Draft'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _saveNotes(finalize: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                    child: const Text('Finalize SOAP Note'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Text(
            'Locked - Finalized Document',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddendumTile(String text, String timestamp) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_edu_rounded,
                color: Color(0xFF64748B),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                timestamp,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.green, size: 12),
              SizedBox(width: 4),
              Text(
                'Digitally Signed',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    int maxLines,
  ) {
    final bool isThisListening = _isListening && _listeningField == hint;
    return Stack(
      alignment: Alignment.topRight,
      children: [
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: _isFinalized,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: _isFinalized ? const Color(0xFFF1F5F9) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            suffixIcon: null,
          ),
        ),
      ],
    );
  }

  Widget _buildIcdSelector() {
    return Column(
      children: [
        if (_icdCode != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Selected: $_icdCode',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                if (!_isFinalized)
                  IconButton(
                    onPressed: () => setState(() => _icdCode = null),
                    icon: const Icon(Icons.close, size: 16, color: Colors.blue),
                  ),
              ],
            ),
          ),
        if (!_isFinalized && _icdCode == null)
          TextField(
            controller: _icdSearchController,
            onChanged: _searchIcd,
            decoration: InputDecoration(
              hintText: 'Search ICD-10 codes...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        if (_icdResults.isNotEmpty && _icdCode == null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _icdResults.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) => ListTile(
                title: Text(
                  _icdResults[i]['code']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(_icdResults[i]['desc']!),
                onTap: () {
                  final code = _icdResults[i]['code']!;
                  setState(() {
                    _icdCode = '$code - ${_icdResults[i]['desc']}';
                    _icdResults = [];
                    _icdSearchController.clear();
                  });
                  _applyTemplate(code);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgramSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Course>(
          value: _selectedProgram,
          hint: const Text('Assign Program'),
          isExpanded: true,
          items: _availablePrograms
              .map((p) => DropdownMenuItem(value: p, child: Text(p.title)))
              .toList(),
          onChanged: _isFinalized
              ? null
              : (val) => setState(() => _selectedProgram = val),
        ),
      ),
    );
  }

  Widget _buildWebView() => _buildMobileView();

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}
