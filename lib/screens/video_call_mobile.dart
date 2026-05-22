import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/agora_config.dart';
import '../services/agora_service.dart';
import '../services/call_service.dart';
import '../utils/shared_pref.dart';

/// Agora RTC video call — Android / iOS / Desktop
class VideoCall extends StatefulWidget {
  final String channelName;
  final String remoteUserName;
  final bool isAudioOnly;
  final String currentUserId;
  final String currentUserName;
  /// Optional appointment ID — used to mark consultation in progress / end
  final String? appointmentId;
  /// Patient's user ID — used to load patient history (doctor-side only)
  final String? patientId;
  /// Optional consultation ID for chat-based consultations
  final String? consultationId;
  /// Overall consultation elapsed seconds — syncs video call timer to chat timer
  final int consultationElapsedSeconds;
  /// Signal ID of the outgoing call — used to detect if patient declined
  final String? outgoingSignalId;
  /// Callback when call ends (to return to chat)
  final VoidCallback? onCallEnded;

  const VideoCall({
    super.key,
    required this.channelName,
    required this.remoteUserName,
    this.isAudioOnly = false,
    this.currentUserId = '',
    this.currentUserName = 'User',
    this.appointmentId,
    this.patientId,
    this.consultationId,
    this.consultationElapsedSeconds = 0,
    this.outgoingSignalId,
    this.onCallEnded,
  });

  @override
  State<VideoCall> createState() => _VideoCallMobileState();
}

class _VideoCallMobileState extends State<VideoCall> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localVideoReady = false;
  bool _joined = false;
  bool _micMuted = false;
  bool _camOff = false;
  bool _loading = true;
  String? _error;
  bool _isDoctor = false;
  bool _remoteJoined = false;
  Timer? _noAnswerTimer;
  Timer? _declinePoller;

  @override
  void initState() {
    super.initState();
    _initRole();
    _initAgora();
  }

  Future<void> _initRole() async {
    try {
      final user = await SharedPref().getUserData();
      if (mounted) {
        setState(() => _isDoctor = user?.role.toLowerCase() == 'doctor');
        if (_isDoctor) {
          _startDeclinePoller();
          _startNoAnswerTimer();
        }
      }
    } catch (_) {}
  }

  void _startDeclinePoller() {
    if (widget.outgoingSignalId == null || widget.outgoingSignalId!.isEmpty) return;
    if (!_isDoctor) return;

    _declinePoller = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || _remoteJoined) {
        _declinePoller?.cancel();
        return;
      }
      try {
        final status = await CallService().checkOutgoingCallStatus(widget.outgoingSignalId!);
        if (status == 'rejected' || status == 'declined') {
          _declinePoller?.cancel();
          _noAnswerTimer?.cancel();
          if (!mounted) return;
          await _engine?.leaveChannel();
          if (!mounted) return;
          _showDeclinedDialog();
        }
      } catch (_) {
        _declinePoller?.cancel();
      }
    });
  }

  void _startNoAnswerTimer() {
    _noAnswerTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _remoteJoined) return;
      _noAnswerTimer?.cancel();
      _engine?.leaveChannel();
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.call_end_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Call Declined / Not Answered'),
          ]),
          content: const Text('The patient declined your call or did not answer.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    });
  }

  void _showDeclinedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.call_end_rounded, color: Colors.red, size: 26),
          SizedBox(width: 10),
          Text('Call Declined'),
        ]),
        content: const Text('The patient has declined your call.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _initAgora() async {
    try {
      // 0. Request camera and microphone permissions at runtime
      if (!kIsWeb) {
        final camStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        if (camStatus.isDenied || micStatus.isDenied) {
          setState(() {
            _error = 'Camera and microphone permissions are required for video calls. Please grant them in Settings.';
            _loading = false;
          });
          return;
        }
        if (camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
          setState(() {
            _error = 'Camera and microphone permissions are permanently denied. Please enable them in App Settings.';
            _loading = false;
          });
          return;
        }
      }

      // 1. Fetch token from backend
      final tokenData = await AgoraService().getToken(
        channelName: widget.channelName,
        uid: 0,
      );

      if (tokenData['success'] != true) {
        setState(() {
          _error = tokenData['message'] ?? 'Failed to get Agora token';
          _loading = false;
        });
        return;
      }

      final token = tokenData['data']['token'] as String;
      final appId = tokenData['data']['appId'] as String? ?? AgoraConfig.appId;

      // 2. Create engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));

      // 3. Register event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            debugPrint('✅ Agora: joined channel ${connection.channelId}');
            if (mounted) setState(() { _joined = true; _loading = false; });
            _startCallTimer();
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            debugPrint('👤 Agora: remote user $remoteUid joined');
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
                _remoteJoined = true;
              });
              _noAnswerTimer?.cancel();
              _declinePoller?.cancel();
            }
          },
          onUserOffline: (connection, remoteUid, reason) {
            debugPrint('👤 Agora: remote user $remoteUid left');
            if (mounted) setState(() => _remoteUid = null);
          },
          onLocalVideoStateChanged: (source, state, error) {
            if (state == LocalVideoStreamState.localVideoStreamStateCapturing ||
                state == LocalVideoStreamState.localVideoStreamStateEncoding) {
              if (mounted) setState(() => _localVideoReady = true);
            }
          },
          onError: (err, msg) {
            debugPrint('❌ Agora error: $err — $msg');
            if (mounted) setState(() { _error = msg; _loading = false; });
          },
        ),
      );

      // 4. Enable video (or audio-only)
      if (!widget.isAudioOnly) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        await _engine!.enableAudio();
      }

      // 5. Set channel profile and client role
      await _engine!.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );

      // 6. Join channel
      await _engine!.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint('❌ Agora init error: $e');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Leave video call only (red button) - with confirmation
  Future<void> _leaveCall() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Video Call'),
        content: const Text('Do you want to leave the video call? You can rejoin from the chat screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;
      if (widget.onCallEnded != null) {
        widget.onCallEnded!();
      }
      if (mounted) Navigator.pop(context);
    }
  }

  /// End Consultation button — with confirmation dialog
  Future<void> _endConsultation() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Consultation'),
        content: const Text('Do you want to end this consultation? This action cannot be undone and you will not be able to rejoin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Consultation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Check if this is a doctor ending consultation (has appointment details)
    if (widget.appointmentId == null || widget.appointmentId!.isEmpty) {
      // No appointment ID - just leave the call (for quick calls)
      try { await CallService().endCall(widget.channelName); } catch (_) {}
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;
      if (mounted) Navigator.pop(context);
      return;
    }

    // Check if current user is doctor
    final currentUser = await SharedPref().getUserData();
    final isDoctor = currentUser?.role.toLowerCase() == 'doctor';

    if (!isDoctor) {
      // Patient cannot end consultation - only leave video
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the doctor can end the consultation'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Doctor ending consultation — leave video and go back to chat screen
    try {
      // Leave video call first
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;

      if (!mounted) return;

      // Pop back to ConsultationChatScreenV2 which is already in the stack
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleMic() async {
    _micMuted = !_micMuted;
    await _engine?.muteLocalAudioStream(_micMuted);
    if (mounted) setState(() {});
  }

  void _toggleCam() async {
    _camOff = !_camOff;
    await _engine?.muteLocalVideoStream(_camOff);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _noAnswerTimer?.cancel();
    _declinePoller?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  int _elapsedSeconds = 0;
  Timer? _callTimer;

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _buildError();
    if (_loading) return _buildLoading();
    if (widget.isAudioOnly) return _buildAudioCallUI();
    return _buildCallUI();
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: Color(0xFF0A1628),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text('Connecting...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 56),
            const SizedBox(height: 16),
            Text(_error ?? 'Unknown error',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          if (_remoteUid != null && !widget.isAudioOnly)
            SizedBox.expand(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: _remoteUid),
                  connection: RtcConnection(channelId: widget.channelName),
                ),
              ),
            )
          else
            _buildWaitingOverlay(),

          // Local video (picture-in-picture)
          if (!widget.isAudioOnly && _localVideoReady)
            Positioned(
              top: 48,
              right: 16,
              width: 110,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),

          // Remote user name
          if (_remoteUid != null)
            Positioned(
              top: 48,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.remoteUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),

          // Controls bar
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _controlBtn(
                      icon: _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: _micMuted ? Colors.grey : Colors.white,
                      bg: Colors.white24,
                      onTap: _toggleMic,
                    ),
                    const SizedBox(width: 20),
                    // Red button — leave video only
                    _controlBtn(
                      icon: Icons.call_end_rounded,
                      color: Colors.white,
                      bg: Colors.red,
                      onTap: _leaveCall,
                      size: 64,
                    ),
                    const SizedBox(width: 20),
                    if (!widget.isAudioOnly)
                      _controlBtn(
                        icon: _camOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        color: _camOff ? Colors.grey : Colors.white,
                        bg: Colors.white24,
                        onTap: _toggleCam,
                      ),
                    const SizedBox(width: 20),
                    // End Consultation button (purple) - camera icon as per client requirements
                    if (widget.appointmentId != null && widget.appointmentId!.isNotEmpty)
                      _controlBtn(
                        icon: Icons.videocam_off_rounded,
                        color: Colors.white,
                        bg: const Color(0xFF7C3AED),
                        onTap: _endConsultation,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Red = Leave Video  •  Purple = End Consultation',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCallUI() {
    final secs = _elapsedSeconds % 60;
    final mins = _elapsedSeconds ~/ 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final initial = widget.remoteUserName.isNotEmpty
        ? widget.remoteUserName[0].toUpperCase()
        : '?';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_in_talk_rounded,
                      color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 6),
                  Text(timeStr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white12,
                  border: Border.all(color: const Color(0xFF10B981), width: 3),
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          fontSize: 48,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.remoteUserName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                _joined ? 'Audio Call' : 'Connecting...',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _controlBtn(
                      icon: _micMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      color: _micMuted ? Colors.grey : Colors.white,
                      bg: Colors.white24,
                      onTap: _toggleMic,
                    ),
                    const SizedBox(width: 24),
                    _controlBtn(
                      icon: Icons.call_end_rounded,
                      color: Colors.white,
                      bg: Colors.red,
                      onTap: _leaveCall,
                      size: 68,
                    ),
                    const SizedBox(width: 24),
                    if (widget.appointmentId != null &&
                        widget.appointmentId!.isNotEmpty)
                      _controlBtn(
                        icon: Icons.videocam_off_rounded,
                        color: Colors.white,
                        bg: const Color(0xFF7C3AED),
                        onTap: _endConsultation,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    return Container(
      color: const Color(0xFF0A1628),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white12,
              child: Text(
                widget.remoteUserName.isNotEmpty
                    ? widget.remoteUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.remoteUserName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Waiting for other party...',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}
