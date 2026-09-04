// Consultation Chat Screen V2 - Chat-First Approach
// Updated as per client requirements - May 4, 2026

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icare/models/consultation_timer.dart';
import 'package:icare/models/consultation_message.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/screens/doctor_consultation_call_screen.dart';
import 'package:icare/screens/patient_history_view.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/services/call_service.dart';
import 'package:icare/services/review_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/rating_dialog.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:icare/utils/utils.dart';

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
  bool _timerSynced = false;
  String? _consultationId;
  bool _showPrescriptionPanel = false;
  Map<String, dynamic>? _prescriptionDraft;
  bool _prescriptionLoading = false;
  // Read off the consultation record when the screen is opened by URL and has
  // neither an appointment nor a remoteUserName to name the other party with.
  String? _fetchedDoctorName;
  String? _fetchedPatientName;

  @override
  void initState() {
    super.initState();
    // Cap Flutter's image cache to 40 MB to prevent "Aw Snap" OOM crashes
    // during long consultations where images accumulate unreleased in the cache.
    PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024;
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

  // The other party's user id, read off the consultation record.
  Future<String> _fetchCounterpartId() async {
    try {
      final res = await _consultationService.getConsultationV2(_consultationId!);
      final c = (res['consultation'] ?? res) as Map<String, dynamic>?;
      if (c == null) return '';
      final raw = widget.isDoctor ? c['patientId'] : c['doctorId'];
      if (raw is Map) return raw['_id']?.toString() ?? '';
      return raw?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  // Fire-and-forget: the header shows whatever it has until these arrive.
  Future<void> _loadParticipantNames(String consultationId) async {
    try {
      final res = await _consultationService.getConsultationV2(consultationId);
      final c = (res['consultation'] ?? res) as Map<String, dynamic>?;
      if (c == null || !mounted) return;
      String? nameOf(dynamic v) {
        if (v is Map) {
          final n = v['name']?.toString();
          return (n != null && n.isNotEmpty) ? n : null;
        }
        return null;
      }
      final doc = nameOf(c['doctorId']);
      final pat = nameOf(c['patientId']);
      if (doc == null && pat == null) return;
      // Assign only what actually resolved. Writing both unconditionally meant
      // that when one side came back populated and the other didn't, the
      // missing one was overwritten with null — which is why the patient's
      // name disappeared from the header on a page reload while the doctor's
      // stayed.
      setState(() {
        if (doc != null) _fetchedDoctorName = doc;
        if (pat != null) _fetchedPatientName = pat;
      });
    } catch (_) {}
  }

  Future<void> _initializeConsultation() async {
    try {
      // consultationId already provided (started from booking card)
      // Backend already created the session and sent consent messages — just load
      if (widget.consultationId != null && widget.consultationId!.isNotEmpty) {
        _consultationId = widget.consultationId;
        // Names for the header — needed when this screen was opened straight
        // from /consultation/<id> (a page reload), where there's no appointment
        // object and no remoteUserName to fall back on.
        if (widget.appointment == null) {
          _loadParticipantNames(widget.consultationId!);
        }
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

      // No consultationId provided — create new consultation (Connect Now flow).
      // The appointment object is optional here (a patient who joined from a
      // call notification has none), so reading the ids only off it sent empty
      // strings and the backend answered "Valid Doctor ID is required". The
      // logged-in user is always one side of the consultation — use that for
      // whichever id the appointment can't supply.
      final apptDoctorId = widget.appointment?.doctor?.id ?? '';
      final apptPatientId = widget.appointment?.patient?.id ?? '';
      final doctorId = apptDoctorId.isNotEmpty
          ? apptDoctorId
          : (widget.isDoctor ? widget.currentUserId : '');
      final patientId = apptPatientId.isNotEmpty
          ? apptPatientId
          : (widget.isDoctor ? '' : widget.currentUserId);

      if (doctorId.isEmpty || patientId.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not start the consultation — missing session details.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final result = await _consultationService.startConsultationV2(
        appointmentId: widget.appointment?.id ?? '',
        patientId: patientId,
        doctorId: doctorId,
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

        // Same timeout safety net as the "already have a consultationId"
        // branch above — this one was missing it, so a slow/loaded backend
        // (confirmed live: doctor's own console showed repeated 30s+
        // getNotifications timeouts around the same rejoin) left _isLoading
        // stuck true with nothing on screen until Dio's own 30s connect/
        // receive timeout eventually fired minutes later.
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
      } else if (mounted) {
        setState(() => _isLoading = false);
        // PAYMENT_REQUIRED (402) means this Connect-Now appointment never
        // got marked paid — often a stale/abandoned booking from before the
        // cash-option-on-Connect-Now bug was fixed, not a real failure.
        // Show a clear message instead of the raw backend text (which reads
        // like a crash: "Waiting for patient to complete payment...").
        final code = result['code']?.toString();
        final message = switch (code) {
          // The session was abandoned rather than ended cleanly; the backend
          // has just settled the stale appointment row, so the rejoin card
          // this came from is gone on the next load.
          'SESSION_ENDED' =>
            'That consultation has already ended. Please start a new one.',
          'PAYMENT_REQUIRED' =>
            'This booking was never paid for, so it can\'t be resumed. Please start a new consultation.',
          _ => (result['message']?.toString() ?? 'Failed to start consultation'),
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        // Nothing to show behind the message — this screen opened only to
        // resume a session that no longer exists.
        if (code == 'SESSION_ENDED' || code == 'PAYMENT_REQUIRED') {
          _exitToDashboard();
        }
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

  // Poll for new messages every 8 seconds — 4 s caused memory pressure over long sessions
  void _startMessagePolling() {
    _messagePollTimer?.cancel();
    _messagePollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _consultationId != null) {
        _loadMessages(silent: true).catchError((_) {});
      }
    });
  }

  Future<void> _sendConsentMessage() async {
    final consentMessage = 'Hi, I am Dr. ${widget.currentUserName}. I confirm that telehealth has limitations and some emergencies require in-person visits.';
    
    await _consultationService.sendMessageV2(
      consultationId: _consultationId!,
      senderId: widget.currentUserId,
      senderName: withDoctorTitle(widget.currentUserName),
      senderRole: 'doctor',
      message: consentMessage,
      isSystemMessage: true,
    );
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_consultationId == null) return;
    try {
      final messages = await _consultationService.getMessagesV2(
          consultationId: _consultationId!);
      if (mounted) {
        var newList = messages
            .map((m) => ConsultationMessage.fromJson(m as Map<String, dynamic>))
            .toList();
        // Keep only the last 100 messages to bound memory usage
        if (newList.length > 100) newList = newList.sublist(newList.length - 100);
        final hadNewMessages = newList.length != _messages.length;
        // Only replace messages if we got a valid non-empty response
        if (newList.isNotEmpty || _messages.isEmpty) {
          setState(() {
            _messages = newList;
            if (!silent) _isLoading = false;
          });
        } else if (!silent && mounted) {
          setState(() => _isLoading = false);
        }
        // Sync timer from EARLIEST message timestamp (both doctor & patient show same time)
        if (newList.isNotEmpty && !_timerSynced) {
          _timerSynced = true;
          // Use min timestamp — messages may not be sorted oldest-first
          final earliest = newList.reduce((a, b) =>
              a.timestamp.isBefore(b.timestamp) ? a : b);
          _timer.syncFromStartTime(earliest.timestamp);
        }
        if (hadNewMessages) _scrollToBottom();
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

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _consultationService.sendMessageV2(
        consultationId: _consultationId!,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        senderRole: widget.isDoctor ? 'doctor' : 'patient',
        message: message,
      );
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

      // Match the backend's own multer cap (consultationRoutes.js: 10 MB).
      // This was pinned at 4 MB for Vercel's 4.5 MB request limit, which no
      // longer applies now that the API runs on our own server — files
      // between 4 and 10 MB were being rejected client-side even though the
      // upload would have succeeded.
      final fileSize = file.bytes?.length ?? file.size;
      if (fileSize > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File too large. Maximum size is 10 MB. Please compress the file and try again.'),
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
        final ext = fileName.split('.').last.toLowerCase();
        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
        final attachmentLabel = isImage ? '[Image]' : '[Document]';
        await _consultationService.sendMessageV2(
          consultationId: _consultationId!,
          senderId: widget.currentUserId,
          senderName: widget.currentUserName,
          senderRole: widget.isDoctor ? 'doctor' : 'patient',
          message: attachmentLabel,
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
    // Determine the other party's ID to send them a ring signal. After a page
    // reload there's no appointment object, so fall back to the ids on the
    // consultation record — otherwise calling was simply impossible from a
    // reloaded consultation.
    var receiverId = widget.isDoctor
        ? widget.appointment?.patient?.id ?? ''
        : widget.appointment?.doctor?.id ?? '';

    if (receiverId.isEmpty && _consultationId != null) {
      receiverId = await _fetchCounterpartId();
    }

    if (receiverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot determine call recipient')),
      );
      return;
    }

    final channelName = _consultationId ?? widget.appointment?.id ?? 'consultation';
    // For patients who joined via call notification, appointment may be null —
    // fall back to the remoteUserName passed into this screen (the caller's name).
    final appointmentDoctorName = widget.appointment?.doctor?.name;
    final remoteUserName = widget.isDoctor
        ? (widget.appointment?.patient?.name ?? _fetchedPatientName ?? widget.remoteUserName ?? 'Patient')
        : (appointmentDoctorName != null && appointmentDoctorName.isNotEmpty
            ? withDoctorTitle(appointmentDoctorName)
            : (_fetchedDoctorName != null
                ? withDoctorTitle(_fetchedDoctorName)
                : (widget.remoteUserName ?? 'Dr. Doctor')));

    // Send ring signal to the other party via call signaling backend
    final callService = CallService();
    // Doctor calls with "Dr. [name]" so patient sees proper title
    final callerDisplayName = widget.isDoctor
        ? (widget.currentUserName.startsWith('Dr.') ? widget.currentUserName : withDoctorTitle(widget.currentUserName))
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

    if (!mounted) return;

    // Doctor's own call screen carries the Prescription/History in-call
    // panels (client's explicit instruction: those no longer live as chat-
    // screen buttons, only inside the live call — see
    // doctor_consultation_call_screen.dart). Needs a real appointment +
    // consultationId to embed PatientHistoryFormScreen (which requires a
    // non-null AppointmentDetail); the patient side never had those panels
    // and keeps the plain call screen.
    debugPrint('🩺 _initiateCall panel-gate check: isDoctor=${widget.isDoctor} '
        'appointment=${widget.appointment != null} consultationId=$_consultationId');
    if (widget.isDoctor && widget.appointment != null && _consultationId != null && _consultationId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => DoctorConsultationCallScreen(
            appointment: widget.appointment!,
            consultationId: _consultationId!,
            remoteUserName: remoteUserName,
            isAudioOnly: audioOnly,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            consultationElapsedSeconds: _timer.elapsed.inSeconds,
            outgoingSignalId: signalId,
          ),
        ),
      );
      return;
    }

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

  // Navigator.pop leaves the screen exactly where it was whenever this
  // route is the bottom of the stack — which is always the case after a
  // page refresh (or opening the /consultation/:id URL directly), since
  // GoRouter rebuilds the whole navigator from that one location. With
  // no route underneath to pop back to, "end consultation" silently did
  // nothing and the user was stuck staring at a blank page. Going to the
  // role's dashboard by location always lands somewhere real, regardless
  // of what (if anything) is under this route on the stack.
  void _exitToDashboard() {
    if (!mounted) return;
    context.go(widget.isDoctor ? '/doctor/dashboard' : '/patient/home');
  }

  Future<void> _endConsultation({bool skipPrescriptionCheck = false}) async {
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

    // Check prescription completion (doctor only). Prescription now only
    // exists as an in-call panel (DoctorConsultationCallScreen), a separate
    // screen instance — so completion is checked against the backend
    // instead of a local flag, which would otherwise always read false here
    // even after a prescription was genuinely completed during the call.
    // skipPrescriptionCheck is set when the doctor already chose "End
    // Without Rx" on the incomplete-prescription dialog below — without it,
    // re-checking here would find the backend still says incomplete and
    // loop straight back into the same dialog.
    if (!skipPrescriptionCheck && widget.isDoctor && _consultationId != null && _consultationId!.isNotEmpty) {
      bool complete = false;
      try {
        // Check the issued prescription first. Once the doctor completes one it
        // leaves the draft collection, so looking only at the draft reported
        // "incomplete" for a consultation that already had a finished
        // prescription emailed to the patient — the doctor was then forced
        // through an "End Without Rx" dialog for a prescription they'd written.
        final issued = await _consultationService.getPrescriptionByConsultation(_consultationId!);
        complete = issued != null && issued.isNotEmpty;
      } catch (_) {}
      if (!complete) {
        try {
          final draft = await _consultationService.getPrescriptionDraft(_consultationId!);
          // Any prescription record means the doctor wrote one — show dialog only
          // when there is literally nothing saved at all.
          complete = draft != null;
        } catch (_) {}
      }
      if (!complete) {
        _showPrescriptionIncompleteDialog();
        return;
      }
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
        final result = _consultationId != null
            ? await _consultationService.endConsultationV2(
                consultationId: _consultationId!,
                duration: _timer.elapsed.inSeconds,
              )
            : {'success': false, 'message': 'No active consultation session'};

        if (result['success'] == true && mounted) {
          _timer.stop();
          await _clearConsultationState();
          
          // Show rating dialog to patient immediately after consultation ends
          if (mounted && !widget.isDoctor) {
            var apptId = widget.appointment?.id ?? '';
            var doctorId = widget.appointment?.doctor?.id ?? '';
            // An instant "Connect Now" consultation is opened without an
            // appointment object, so both ids were blank and the patient was
            // sent to the dashboard without ever being asked to rate. Fall
            // back to the consultation record, which always has them.
            if ((apptId.isEmpty || doctorId.isEmpty) && _consultationId != null) {
              try {
                final res = await _consultationService.getConsultationV2(_consultationId!);
                final c = (res['consultation'] ?? res) as Map<String, dynamic>?;
                if (c != null) {
                  if (apptId.isEmpty) apptId = c['appointmentId']?.toString() ?? '';
                  if (doctorId.isEmpty) {
                    final d = c['doctorId'];
                    doctorId = (d is Map ? d['_id'] : d)?.toString() ?? '';
                  }
                }
              } catch (_) {}
            }
            if (doctorId.isNotEmpty && mounted) {
              await showRatingDialog(
                context: context,
                title: 'Rate Your Doctor',
                subtitle: 'How was your consultation experience?',
                onSubmit: (rating, satisfied, comment) async {
                  // Never let a failed review keep the patient on this screen —
                  // the consultation has already ended by this point.
                  if (apptId.isEmpty) return;
                  try {
                    await ReviewService().submitReview(
                      appointmentId: apptId,
                      doctorId: doctorId,
                      starRating: rating,
                      satisfied: satisfied,
                      reviewText: comment.isNotEmpty ? comment : null,
                    );
                  } catch (_) {}
                },
              );
            }
            if (!mounted) return;
            // Go straight to the patient's dashboard. The prescription (if
            // any) is available from their Prescriptions page — stopping here
            // to show a FutureBuilder screen left the patient stranded because
            // the screen required a manual "Go to Dashboard" tap rather than
            // redirecting automatically.
            _exitToDashboard();
          } else {
            // Doctor side - just go back
            _exitToDashboard();
          }
        } else if (mounted) {
          // Backend returned success: false — show error with force-exit option
          final errorMsg = result['message']?.toString() ?? 'Server error';
          final forceEnd = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Unable to End Consultation'),
              content: Text(
                  'Could not end on server: $errorMsg\n\nWould you like to exit anyway?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Stay'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Exit Anyway'),
                ),
              ],
            ),
          );
          if (forceEnd == true && mounted) {
            _timer.stop();
            await _clearConsultationState();
            _exitToDashboard();
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

  Future<void> _fetchAndTogglePrescription() async {
    if (widget.isDoctor) return;
    if (_showPrescriptionPanel) {
      setState(() => _showPrescriptionPanel = false);
      return;
    }
    setState(() { _prescriptionLoading = true; _showPrescriptionPanel = true; });
    try {
      final id = _consultationId;
      if (id != null && id.isNotEmpty) {
        _prescriptionDraft = await _consultationService.getPrescriptionDraft(id);
      }
    } catch (_) {}
    if (mounted) setState(() => _prescriptionLoading = false);
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
          'You have not completed a prescription for this consultation. '
          'Prescription can only be filled in during the video/audio call — '
          'start a call to add it, or end the consultation without one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endConsultation(skipPrescriptionCheck: true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Without Rx'),
          ),
        ],
      ),
    );
  }

  /// Back out of a live consultation.
  ///
  /// Leaving used to just drop the screen: the consultation stayed `active`
  /// on the backend and its appointment stayed `in_progress`, so the patient
  /// was left with a "Rejoin" card for a session nobody was in — and enough
  /// of those piled up to show several "Consultation in Progress" rows at
  /// once. Make the choice explicit instead of guessing for the user.
  Future<bool> _confirmLeave() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave consultation?'),
        content: const Text(
          'You can step away and come back to this session, or end it now for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'leave'),
            child: const Text('Leave (keep session)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'end'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End consultation'),
          ),
        ],
      ),
    );
    if (choice == 'end') {
      await _endConsultation();
      return false; // _endConsultation navigates on its own
    }
    return choice == 'leave';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) _exitToDashboard();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildConsultationHeader(),
                if (!widget.isDoctor && _showPrescriptionPanel)
                  _buildPatientPrescriptionPanel(),
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
      ),
    );
  }

  // ── Patient read-only prescription panel ────────────────────────────────
  Widget _buildPatientPrescriptionPanel() {
    final draft = _prescriptionDraft;
    final diagnoses = (draft?['diagnoses'] as List? ?? []);
    final medicines = (draft?['medicines'] as List? ??
        draft?['prescription']?['medicines'] as List? ?? []);
    final notes = draft?['notes']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0049E6).withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0049E6).withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_rounded, color: Color(0xFF0049E6), size: 18),
                const SizedBox(width: 8),
                const Text('Prescription (Live)', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0049E6), fontSize: 14)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showPrescriptionPanel = false),
                  child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF0049E6)),
                ),
              ],
            ),
          ),
          // Body
          _prescriptionLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : (draft == null || (diagnoses.isEmpty && medicines.isEmpty && notes.isEmpty))
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No prescription added yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (diagnoses.isNotEmpty) ...[
                            const Text('Diagnoses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
                            const SizedBox(height: 4),
                            ...diagnoses.map((d) {
                              final name = d is Map ? (d['diagnosis']?.toString() ?? d['name']?.toString() ?? '') : d.toString();
                              final code = d is Map ? (d['icd10Code']?.toString() ?? '') : '';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('• $name${code.isNotEmpty ? " ($code)" : ""}', style: const TextStyle(fontSize: 13)),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                          if (medicines.isNotEmpty) ...[
                            const Text('Medicines', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
                            const SizedBox(height: 4),
                            ...medicines.map((m) {
                              final name = m is Map ? (m['medicineName']?.toString() ?? m['name']?.toString() ?? '') : m.toString();
                              final dose = m is Map ? (m['dosage']?.toString() ?? m['dose']?.toString() ?? '') : '';
                              final freq = m is Map ? (m['frequency']?.toString() ?? '') : '';
                              final dur = m is Map ? (m['duration']?.toString() ?? '') : '';
                              final detail = [if (dose.isNotEmpty) dose, if (freq.isNotEmpty) freq, if (dur.isNotEmpty) dur].join(' · ');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontSize: 13)),
                                    Expanded(child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        if (detail.isNotEmpty)
                                          Text(detail, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    )),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                          if (notes.isNotEmpty) ...[
                            const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
                            const SizedBox(height: 4),
                            Text(notes, style: const TextStyle(fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
        ],
      ),
    );
  }

  // ── Screenshot-matched consultation header ──────────────────────────────
  Widget _buildConsultationHeader() {
    // When appointment is available use its names;
    // when null (patient joined via call notification) use current/remote names.
    // Treat placeholder names ('Doctor', 'Patient') as missing — fall back to real names
    final apptPatientName = widget.appointment?.patient?.name;
    final patientName = (apptPatientName != null && apptPatientName != 'Patient' && apptPatientName.isNotEmpty)
        ? apptPatientName
        // _fetchedPatientName covers the reload case: opening
        // /consultation/<id> by URL has no appointment and no remoteUserName,
        // so the header used to fall back to the literal "Patient"/"Doctor".
        : (!widget.isDoctor
            ? widget.currentUserName
            : (_fetchedPatientName ?? widget.remoteUserName ?? 'Patient'));
    final apptDoctorName = widget.appointment?.doctor?.name;
    final doctorName = (apptDoctorName != null && apptDoctorName != 'Doctor' && apptDoctorName.isNotEmpty)
        ? apptDoctorName
        : (widget.isDoctor
            ? widget.currentUserName
            : (_fetchedDoctorName ?? widget.remoteUserName?.replaceFirst('Dr. ', '') ?? 'Doctor'));
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
                        _participantRow(Icons.medical_services_outlined, withDoctorTitle(doctorName)),
                      ],
                    ),
                  ),
                  // Prescription and History Form moved into the in-call
                  // panel (DoctorConsultationCallScreen) — only accessible
                  // during the live call now, per client's explicit
                  // instruction. Past Consultations stays here.
                  if (widget.isDoctor) ...[
                    IconButton(
                      icon: const Icon(Icons.history_rounded, size: 22),
                      color: AppColors.primaryColor,
                      onPressed: _openPastConsultations,
                      tooltip: 'Past Consultations',
                    ),
                  ],
                  if (!widget.isDoctor) ...[
                    IconButton(
                      icon: Icon(
                        _showPrescriptionPanel
                            ? Icons.description_rounded
                            : Icons.description_outlined,
                        size: 22,
                      ),
                      color: AppColors.primaryColor,
                      onPressed: _fetchAndTogglePrescription,
                      tooltip: 'View Prescription',
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
    // Keep this widget safe even if a future timer implementation supplies an
    // empty/short value during an asynchronous rebuild.
    final digits = value.padLeft(2, '0');
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
                digits[0],
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(width: 2),
              Text(
                digits[1],
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
              if (message.message.isNotEmpty &&
                  message.message != '[Image]' &&
                  message.message != '[Document]')
                const SizedBox(height: 8),
            ],
            // Hide auto-generated attachment labels — show real captions only
            if (message.message.isNotEmpty &&
                message.message != '[Image]' &&
                message.message != '[Document]')
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
        lower.endsWith('.png') || lower.endsWith('.gif') || lower.endsWith('.webp') ||
        (lower.contains('cloudinary.com') && lower.contains('/image/upload/'));
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

