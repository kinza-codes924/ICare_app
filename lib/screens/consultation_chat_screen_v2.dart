// Consultation Chat Screen V2 - Chat-First Approach
// Updated as per client requirements - May 4, 2026

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icare/models/consultation_timer.dart';
import 'package:icare/models/consultation_message.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/models/enhanced_prescription.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/screens/in_consultation_prescription_form.dart';
import 'package:icare/screens/patient_history_form_screen.dart';
import 'package:icare/screens/patient_history_view.dart';
import 'package:icare/screens/prescription_pdf_view_screen.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/services/call_service.dart';
import 'package:icare/services/review_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/rating_dialog.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsultationChatScreenV2 extends StatefulWidget {
  final AppointmentDetail? appointment; // nullable — may be null for patient accepting call
  final bool isDoctor;
  final String currentUserId;
  final String currentUserName;
  final String? consultationId; // Optional - if already created
  final String? remoteUserName; // Doctor name when patient joins via call notification

  const ConsultationChatScreenV2({
    super.key,
    this.appointment, // optional
    required this.isDoctor,
    required this.currentUserId,
    required this.currentUserName,
    this.consultationId,
    this.remoteUserName,
  });

  @override
  State<ConsultationChatScreenV2> createState() => _ConsultationChatScreenV2State();
}

class _ConsultationChatScreenV2State extends State<ConsultationChatScreenV2> {
  final ConsultationService _consultationService = ConsultationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late ConsultationTimer _timer;
  Timer? _messagePollTimer;          // polls for new messages every 4 s
  List<ConsultationMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _prescriptionComplete = false;
  bool _timerSynced = false;
  String? _consultationId;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
    _initializeConsultation();
  }

  void _initializeTimer() {
    _timer = ConsultationTimer(
      onTick: (duration) {
        if (mounted) setState(() {});
      },
      onMinimumReached: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Minimum consultation duration reached. You can now end the consultation.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
      onWarningBeforeMax: () {
        if (mounted) {
          _showWarningDialog();
        }
      },
      onMaximumReached: () {
        if (mounted) {
          _showMaximumReachedDialog();
        }
      },
    );
    _timer.start();
    // Save consultation start time so VideoCall can sync timer (both doctor & patient)
    SharedPreferences.getInstance().then((prefs) {
      final consultKey = 'consult_start_${widget.consultationId ?? ""}';
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!prefs.containsKey(consultKey)) prefs.setInt(consultKey, now);
    });
  }

  Future<void> _initializeConsultation() async {
    try {
      // consultationId already provided (started from booking card)
      // Backend already created the session and sent consent messages — just load
      if (widget.consultationId != null && widget.consultationId!.isNotEmpty) {
        _consultationId = widget.consultationId;
        // Load messages with a timeout — don't block UI if backend is slow
        await _loadMessages().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // Timeout is fine — show empty chat, polling will catch up
          },
        );
        if (mounted) {
          setState(() => _isLoading = false);
          _startMessagePolling();
        }
        return;
      }

      // No consultationId provided — create new consultation (Connect Now flow)
      final result = await _consultationService.startConsultationV2(
        appointmentId: widget.appointment?.id ?? '',
        patientId: widget.appointment?.patient?.id ?? '',
        doctorId: widget.appointment?.doctor?.id ?? '',
      );

      if (result['success'] == true) {
        final rawId = result['consultationId']?.toString() ?? '';
        _consultationId = rawId.isNotEmpty ? rawId : null;

        if (_consultationId == null) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Consultation created but ID missing. Please try again.')),
            );
          }
          return;
        }

        // Doctor sends consent message automatically at consultation start
        if (widget.isDoctor) {
          await _sendConsentMessage().catchError((_) {});
        }

        await _loadMessages();
        if (mounted) {
          setState(() => _isLoading = false);
          _startMessagePolling();
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Failed to start consultation')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Poll for new messages every 4 seconds so both parties see updates in real-time
  void _startMessagePolling() {
    _messagePollTimer?.cancel();
    _messagePollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _consultationId != null) {
        _loadMessages(silent: true).catchError((_) {}); // catch unhandled Future errors
      }
    });
  }

  Future<void> _sendConsentMessage() async {
    final consentMessage = 'Hi, I am Dr. ${widget.currentUserName}. I confirm that telehealth has limitations and some emergencies require in-person visits.';
    
    await _consultationService.sendMessageV2(
      consultationId: _consultationId!,
      senderId: widget.currentUserId,
      senderName: 'Dr. ${widget.currentUserName}',
      senderRole: 'doctor',
      message: consentMessage,
      isSystemMessage: true,
    );
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_consultationId == null) return;
    try {
      print('📥 LOADING MESSAGES for consultationId: $_consultationId');
      final messages = await _consultationService.getMessagesV2(
          consultationId: _consultationId!);
      print('📥 RECEIVED ${messages.length} messages');
      if (mounted) {
        final newList = messages
            .map((m) => ConsultationMessage.fromJson(m as Map<String, dynamic>))
            .toList();
        final hadNewMessages = newList.length != _messages.length;
        print('📥 Previous message count: ${_messages.length}, New count: ${newList.length}');
        setState(() {
          _messages = newList;
          if (!silent) _isLoading = false;
        });
        // Sync timer from EARLIEST message timestamp (both doctor & patient show same time)
        if (newList.isNotEmpty && !_timerSynced) {
          _timerSynced = true;
          // Use min timestamp — messages may not be sorted oldest-first
          final earliest = newList.reduce((a, b) =>
              a.timestamp.isBefore(b.timestamp) ? a : b);
          _timer.syncFromStartTime(earliest.timestamp);
        }
        if (hadNewMessages) {
          print('📥 New messages detected, scrolling to bottom');
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('❌ ERROR LOADING MESSAGES: $e');
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending || _consultationId == null) return;

    print('📤 SENDING MESSAGE:');
    print('  consultationId: $_consultationId');
    print('  senderId: ${widget.currentUserId}');
    print('  senderName: ${widget.currentUserName}');
    print('  senderRole: ${widget.isDoctor ? 'doctor' : 'patient'}');
    print('  message: $message');

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final result = await _consultationService.sendMessageV2(
        consultationId: _consultationId!,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        senderRole: widget.isDoctor ? 'doctor' : 'patient',
        message: message,
      );
      print('📤 SEND MESSAGE RESULT: $result');
      await _loadMessages();
    } catch (e) {
      print('❌ ERROR IN _sendMessage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_consultationId == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true, // always read bytes — works on web + mobile
      );

      if (result == null) return;
      final file = result.files.single;
      final fileName = file.name;

      // Guard: max 4MB (Vercel 4.5MB limit with headroom)
      final fileSize = file.bytes?.length ?? file.size;
      if (fileSize > 4 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File too large. Maximum size is 4 MB. Please compress the image and try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      Map<String, dynamic> uploadResult;

      final Uint8List? bytes = file.bytes;
      if (bytes != null) {
        uploadResult = await _consultationService.uploadAttachmentBytes(
          bytes: bytes,
          fileName: fileName,
        );
      } else if (file.path != null) {
        uploadResult = await _consultationService.uploadAttachment(file.path!);
      } else {
        throw Exception('Could not read file');
      }

      // Accept both {success:true, url:...} and bare {url:...} from backend
      final url = uploadResult['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        await _consultationService.sendMessageV2(
          consultationId: _consultationId!,
          senderId: widget.currentUserId,
          senderName: widget.currentUserName,
          senderRole: widget.isDoctor ? 'doctor' : 'patient',
          message: '📎 $fileName',
          attachmentUrl: url,
        );
        await _loadMessages();
      } else if (uploadResult['success'] == true) {
        throw Exception('Upload succeeded but no URL returned');
      } else {
        throw Exception(uploadResult['message']?.toString() ?? 'Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _initiateCall({required bool audioOnly}) async {
    // Determine the other party's ID to send them a ring signal
    final receiverId = widget.isDoctor
        ? widget.appointment?.patient?.id ?? ''
        : widget.appointment?.doctor?.id ?? '';

    if (receiverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot determine call recipient')),
      );
      return;
    }

    final channelName = _consultationId ?? widget.appointment?.id ?? 'consultation';
    final remoteUserName = widget.isDoctor
        ? widget.appointment?.patient?.name ?? 'Patient'
        : 'Dr. ${widget.appointment?.doctor?.name ?? 'Doctor'}';

    // Send ring signal to the other party via call signaling backend
    final callService = CallService();
    // Doctor calls with "Dr. [name]" so patient sees proper title
    final callerDisplayName = widget.isDoctor
        ? (widget.currentUserName.startsWith('Dr.') ? widget.currentUserName : 'Dr. ${widget.currentUserName}')
        : widget.currentUserName;
    final callResult = await callService.initiateCall(
      receiverId: receiverId,
      channelName: channelName,
      callerName: callerDisplayName,
      callType: audioOnly ? 'audio' : 'video',
    );

    // Extract signalId for decline detection
    final signalId = callResult['signal']?['_id']?.toString()
        ?? callResult['signal']?['id']?.toString()
        ?? callResult['signalId']?.toString()
        ?? callResult['_id']?.toString();

    if (!mounted) return;

    // Save start time keyed by channelName so patient VideoCall can sync
    SharedPreferences.getInstance().then((prefs) {
      final key = 'consult_start_$channelName';
      if (!prefs.containsKey(key)) {
        prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
      }
    });

    // Open call screen for the caller immediately
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => VideoCall(
          channelName: channelName,
          remoteUserName: remoteUserName,
          isAudioOnly: audioOnly,
          appointmentId: widget.appointment?.id,
          consultationId: _consultationId,
          patientId: widget.appointment?.patient?.id,
          currentUserName: widget.currentUserName,
          currentUserId: widget.currentUserId,
          consultationElapsedSeconds: _timer.elapsed.inSeconds,
          outgoingSignalId: signalId,
        ),
      ),
    );
  }

  void _startVideoCall() => _initiateCall(audioOnly: false);
  void _startVoiceCall() => _initiateCall(audioOnly: true);

  void _openPastConsultations() {
    if (!widget.isDoctor) return;
    final patient = widget.appointment?.patient;
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient info not available')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PatientHistoryView(patient: patient),
      ),
    );
  }

  void _openHistoryForm() {
    if (!widget.isDoctor) return;
    if (_consultationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation not initialized yet')),
      );
      return;
    }
    if (widget.appointment == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PatientHistoryFormScreen(
          appointment: widget.appointment!,
          consultationId: _consultationId!,
        ),
      ),
    );
  }

  void _openPrescriptionForm() {
    if (!widget.isDoctor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only doctors can create prescriptions')),
      );
      return;
    }
    if (widget.appointment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment not initialized'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_consultationId == null || _consultationId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation session not ready. Please wait a moment.'), backgroundColor: Colors.orange),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => InConsultationPrescriptionForm(
          appointment: widget.appointment!,
          consultationId: _consultationId!,
          onPrescriptionComplete: (isComplete) {
            setState(() => _prescriptionComplete = isComplete);
          },
        ),
      ),
    );
  }

  Future<void> _endConsultation() async {
    // Validate minimum duration
    final validationError = _timer.validateEndConsultation();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check prescription completion (doctor only)
    if (widget.isDoctor && !_prescriptionComplete) {
      _showPrescriptionIncompleteDialog();
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Consultation'),
        content: const Text(
          'Are you sure you want to end this consultation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('End Consultation'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _consultationService.endConsultationV2(
          consultationId: _consultationId!,
          duration: _timer.elapsed.inSeconds,
        );
        if (result['success'] == true && mounted) {
          _timer.stop();
          await _clearConsultationState();
          
          // Show rating dialog to patient immediately after consultation ends
          if (mounted && !widget.isDoctor) {
            final apptId = widget.appointment?.id ?? '';
            final doctorId = widget.appointment?.doctor?.id ?? '';
            if (apptId.isNotEmpty && mounted) {
              await showRatingDialog(
                context: context,
                title: 'Rate Your Doctor',
                subtitle: 'How was your consultation experience?',
                onSubmit: (rating, satisfied, comment) async {
                  await ReviewService().submitReview(
                    appointmentId: apptId,
                    doctorId: doctorId,
                    starRating: rating,
                    satisfied: satisfied,
                    reviewText: comment.isNotEmpty ? comment : null,
                  );
                },
              );
            }
            if (!mounted) return;
            // Then show prescription if available
            final prescriptionId = result['prescriptionId']?.toString();
            if (prescriptionId != null && prescriptionId.isNotEmpty) {
              // Navigate to prescription view
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => FutureBuilder(
                    future: _consultationService.getPrescription(prescriptionId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Scaffold(
                          appBar: AppBar(title: const Text('Consultation Ended')),
                          body: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                                const SizedBox(height: 16),
                                const Text('Consultation completed successfully'),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                                  child: const Text('Go to Dashboard'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      // Show prescription
                      final prescriptionData = snapshot.data as Map<String, dynamic>;
                      return PrescriptionPdfViewScreen(
                        prescription: EnhancedPrescription.fromJson(prescriptionData['prescription']),
                        patientData: prescriptionData['patient'],
                        doctorData: prescriptionData['doctor'],
                      );
                    },
                  ),
                ),
              );
            } else {
              // No prescription - just show success and go back
              if (mounted) Navigator.pop(context);
            }
          } else {
            // Doctor side - just go back
            if (mounted) Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to end consultation: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearConsultationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('doctor_in_consultation', false);
    } catch (_) {}
  }

  void _showWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Consultation Ending Soon'),
          ],
        ),
        content: Text(
          'The consultation will automatically end in ${_timer.remainingTimeFormatted}. Please wrap up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMaximumReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Maximum Duration Reached'),
        content: const Text(
          'The maximum consultation duration of 30 minutes has been reached. The consultation will now end.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endConsultation();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrescriptionIncompleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Prescription Incomplete'),
          ],
        ),
        content: const Text(
          'You have not completed a prescription for this consultation. Would you like to add one, or end without a prescription?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _prescriptionComplete = true);
              _endConsultation();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Without Rx'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openPrescriptionForm();
            },
            child: const Text('Add Prescription'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildConsultationHeader(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  // ── Screenshot-matched consultation header ──────────────────────────────
  Widget _buildConsultationHeader() {
    // When appointment is available use its names;
    // when null (patient joined via call notification) use current/remote names.
    final patientName = widget.appointment?.patient?.name
        ?? (!widget.isDoctor ? widget.currentUserName : (widget.remoteUserName ?? 'Patient'));
    final doctorName = widget.appointment?.doctor?.name
        ?? (widget.isDoctor ? widget.currentUserName : (widget.remoteUserName?.replaceFirst('Dr. ', '') ?? 'Doctor'));
    final mins = (_timer.elapsed.inSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_timer.elapsed.inSeconds % 60).toString().padLeft(2, '0');

    final timerColor = (_timer.status == ConsultationTimerStatus.nearMaximum ||
            _timer.status == ConsultationTimerStatus.reachedMaximum)
        ? Colors.red
        : (_timer.status == ConsultationTimerStatus.belowMinimum
            ? Colors.orange
            : AppColors.primaryColor);

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Names row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  const CustomBackButton(),
                  Expanded(
                    child: Column(
                      children: [
                        _participantRow(Icons.person_outline, patientName),
                        const SizedBox(height: 4),
                        _participantRow(Icons.medical_services_outlined, 'Dr. $doctorName'),
                      ],
                    ),
                  ),
                  // Doctor action buttons (past consultations + history + prescription)
                  if (widget.isDoctor) ...[
                    IconButton(
                      icon: const Icon(Icons.history_rounded, size: 22),
                      color: AppColors.primaryColor,
                      onPressed: _openPastConsultations,
                      tooltip: 'Past Consultations',
                    ),
                    IconButton(
                      icon: const Icon(Icons.history_edu_rounded, size: 22),
                      color: AppColors.primaryColor,
                      onPressed: _openHistoryForm,
                      tooltip: 'History Form',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.description_rounded,
                        size: 22,
                        color: _prescriptionComplete ? Colors.green : AppColors.primaryColor,
                      ),
                      onPressed: _openPrescriptionForm,
                      tooltip: 'Prescription',
                    ),
                  ],
                ],
              ),
            ),
            // ── Timer + call buttons row ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // ── Timer digits (Mins | Secs) ──
                  _timerDigits(mins, secs, timerColor),
                  const SizedBox(width: 16),
                  // ── Voice call circular button ──
                  _callButton(
                    icon: Icons.phone_rounded,
                    onTap: _startVoiceCall,
                    tooltip: 'Voice Call',
                  ),
                  const SizedBox(width: 10),
                  // ── Video call circular button ──
                  _callButton(
                    icon: Icons.videocam_rounded,
                    onTap: _startVideoCall,
                    tooltip: 'Video Call',
                  ),
                  const Spacer(),
                  // ── End Consultation button (purple — permanently ends) ──
                  ElevatedButton.icon(
                    onPressed: _endConsultation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.videocam_off_rounded, size: 16),
                    label: const Text(
                      'End Consultation',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            // ── Progress bar ──
            LinearProgressIndicator(
              value: _timer.progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              minHeight: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _participantRow(IconData icon, String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryColor, width: 1.5),
            color: AppColors.primaryColor.withValues(alpha: 0.08),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryColor),
        ),
        const SizedBox(width: 8),
        Text(
          name.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF0F172A),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _timerDigits(String mins, String secs, Color color) {
    return Row(
      children: [
        _digitBox(mins, 'Mins', color),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(' : ', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w900, color: color,
          )),
        ),
        _digitBox(secs, 'Secs', color),
      ],
    );
  }

  Widget _digitBox(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(
                value[0],
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(width: 2),
              Text(
                value[1],
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _callButton({required IconData icon, required VoidCallback onTap, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryColor,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }


  Widget _buildMessageBubble(ConsultationMessage message) {
    final isMe = message.senderId == widget.currentUserId;

    if (message.isSystemMessage) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.message,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1E40AF),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.attachmentUrl != null) ...[
              _buildAttachmentPreview(message.attachmentUrl!, isMe),
              const SizedBox(height: 8),
            ],
            Text(
              message.message,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(String url, bool isMe) {
    final lower = url.toLowerCase();
    final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
        lower.endsWith('.png') || lower.endsWith('.gif') || lower.endsWith('.webp');
    if (isImage) {
      return GestureDetector(
        onTap: () => _showImagePreview(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 180,
            height: 140,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _attachmentIcon(isMe, 'Image'),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _openOrDownloadFile(url),
      child: _attachmentIcon(isMe, url.split('/').last),
    );
  }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: TextButton.icon(
                onPressed: () => _openOrDownloadFile(url),
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                label: const Text('Download', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOrDownloadFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _attachmentIcon(bool isMe, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.attach_file_rounded, size: 16,
            color: isMe ? Colors.white : AppColors.primaryColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.download_rounded, size: 14,
            color: isMe ? Colors.white70 : AppColors.primaryColor),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF64748B)),
            onPressed: _pickAndSendFile,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isSending,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _isSending ? Colors.grey : AppColors.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _timer.stop();
    _messagePollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    
    // Clear doctor_in_consultation flag when leaving consultation
    if (widget.isDoctor) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('doctor_in_consultation', false);
        debugPrint('✅ Cleared doctor_in_consultation flag on dispose');
      });
    }
    
    super.dispose();
  }
}

