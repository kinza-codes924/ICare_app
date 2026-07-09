import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/services/clinical_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class IntakeNotesRedesign extends StatefulWidget {
  final AppointmentDetail? appointment;

  const IntakeNotesRedesign({super.key, this.appointment});

  @override
  State<IntakeNotesRedesign> createState() => _IntakeNotesRedesignState();
}

class _IntakeNotesRedesignState extends State<IntakeNotesRedesign> {
  final _formKey = GlobalKey<FormState>();
  final ClinicalService _clinicalService = ClinicalService();

  final _chiefComplaintController = TextEditingController();
  final _historyController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _socialHistoryController = TextEditingController();
  final _familyHistoryController = TextEditingController();

  late stt.SpeechToText _speech;
  bool _isListening = false;

  bool _isFinalized = false;
  bool _isLoading = true;
  List<String> _attachments = [];
  List<dynamic> _addendums = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadExistingNotes();
  }

  Future<void> _loadExistingNotes() async {
    if (widget.appointment == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final result = await _clinicalService.getIntakeNotes(
        widget.appointment!.id,
      );
      if (result != null &&
          result['success'] == true &&
          result['notes'] != null) {
        final notes = result['notes'];
        setState(() {
          _chiefComplaintController.text = notes['chiefComplaint'] ?? '';
          _historyController.text = notes['history'] ?? '';
          _allergiesController.text =
              (notes['allergies'] as List?)?.join(', ') ?? '';
          _medicationsController.text =
              (notes['medications'] as List?)?.join(', ') ?? '';
          _isFinalized = notes['isFinalized'] ?? false;
          _attachments = List<String>.from(notes['attachments'] ?? []);
          _addendums = List<dynamic>.from(notes['addendums'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading intake notes: $e');
    } finally {
      setState(() => _isLoading = false);
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
                  'intake',
                  addendumController.text,
                );
                Navigator.pop(ctx);
                _loadExistingNotes();
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
    _chiefComplaintController.dispose();
    _historyController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _socialHistoryController.dispose();
    _familyHistoryController.dispose();
    super.dispose();
  }

  void _saveNotes({bool finalize = false}) async {
    if (widget.appointment == null) return;

    setState(() => _isLoading = true);
    try {
      await _clinicalService.saveIntakeNotes(widget.appointment!.id, {
        'chiefComplaint': _chiefComplaintController.text,
        'history': _historyController.text,
        'allergies': _allergiesController.text
            .split(',')
            .map((e) => e.trim())
            .toList(),
        'medications': _medicationsController.text
            .split(',')
            .map((e) => e.trim())
            .toList(),
        'isFinalized': finalize,
        'attachments': _attachments,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalize
                  ? 'Notes finalized successfully'
                  : 'Notes saved successfully',
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
              // Keep cursor at the end
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            }
          });
        },
      );
    }
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
            suffixIcon: _isFinalized
                ? null
                : IconButton(
                    onPressed: () => _startListening(controller, hint),
                    icon: Icon(
                      isThisListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: isThisListening
                          ? Colors.redAccent
                          : AppColors.primaryColor,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _addAttachment() {
    // Simulated Attachment (Req 12.9)
    setState(() {
      _attachments.add('doc_${DateTime.now().millisecondsSinceEpoch}.pdf');
    });
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
          'Intake Notes',
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
                Icons.attach_file_rounded,
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
              if (_isFinalized)
                Container(
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
                        'This note is finalized and cannot be edited.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              _buildSectionTitle('Chief Complaint'),
              _buildTextField(
                _chiefComplaintController,
                'Main reason for visit',
                2,
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('History of Present Illness'),
              _buildTextField(_historyController, 'Detailed history', 4),
              const SizedBox(height: 20),
              _buildSectionTitle('Allergies'),
              _buildTextField(
                _allergiesController,
                'Known allergies (comma separated)',
                2,
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Current Medications'),
              _buildTextField(
                _medicationsController,
                'List of medications (comma separated)',
                3,
              ),

              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Attachments',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryColor,
                      side: const BorderSide(color: AppColors.primaryColor),
                    ),
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
                    child: const Text('Finalize Note'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    // Basic implementation for web consistency
    return _buildMobileView();
  }

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
}
