// Joining a live session from an invite link, without an account.
//
// An instructor sometimes needs someone from outside the course in the room —
// a visiting speaker, an examiner. Enrolling them, or handing over a login,
// is the wrong shape for a one-off appearance.
//
// The link carries a token that belongs to the session. This screen asks only
// for a name to show on the tile, then puts the guest straight into the same
// room the class is in. The guest is never a moderator: they cannot end the
// session, remove anyone, or start a recording.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import '../utils/lms_agora_stub.dart'
    if (dart.library.js_interop) '../utils/lms_agora_web.dart';

class GuestSessionJoinScreen extends StatefulWidget {
  final String inviteToken;
  const GuestSessionJoinScreen({super.key, required this.inviteToken});

  @override
  State<GuestSessionJoinScreen> createState() => _GuestSessionJoinScreenState();
}

class _GuestSessionJoinScreenState extends State<GuestSessionJoinScreen> {
  final LmsService _lms = LmsService();
  final TextEditingController _nameCtrl = TextEditingController();

  Timer? _closedPoller;
  bool _loading = true;
  bool _joining = false;
  bool _inCall = false;
  String? _error;
  String _title = '';
  bool _isLive = false;
  String? _videoViewName;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  @override
  void dispose() {
    _closedPoller?.cancel();
    if (_inCall) {
      try {
        lmsLeaveChannel();
      } catch (_) {}
    }
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Watch for the session ending.
  ///
  /// When the instructor ends it for everyone, or the guest presses hangup,
  /// Jitsi tears its own iframe down and leaves nothing behind — the guest was
  /// left staring at a blank dark page with no way out. A guest has no
  /// dashboard to return to, so send them to the site's front page.
  void _startClosedPoller() {
    _closedPoller?.cancel();
    _closedPoller = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (lmsIsSessionClosed()) {
        _closedPoller?.cancel();
        // A full page load, not a router push: an SPA navigation straight
        // after a Jitsi session leaves dead platform views behind.
        lmsHardRedirect('/home');
      }
    });
  }

  Future<void> _loadInvite() async {
    final info = await _lms.getInviteInfo(widget.inviteToken);
    if (!mounted) return;
    if (info == null) {
      setState(() {
        _loading = false;
        _error = 'This invite link is no longer valid.';
      });
      return;
    }
    setState(() {
      _loading = false;
      _title = (info['title'] ?? 'Live Session').toString();
      _isLive = info['isLive'] == true;
    });

    // The guest types their own name and presses Join. Joining automatically
    // under the placeholder "Guest" put a meaningless label on their tile,
    // and nobody in the session could tell who had walked in. One field and
    // one button is not the step the link exists to skip -- logging in is.
  }

  Future<void> _join() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });

    final result = await _lms.joinAsGuest(widget.inviteToken, name);
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _joining = false;
        _error = result['code'] == 'NOT_LIVE'
            ? 'The session has not started yet. Please try again once it is live.'
            : (result['message'] ?? 'Could not join the session').toString();
      });
      return;
    }

    // Same room, same branding-free config the class is using — the guest
    // simply joins without moderator rights.
    final viewId = registerLmsVideoView();
    setState(() {
      _videoViewName = viewId;
      _inCall = true;
      _joining = false;
    });

    try {
      await lmsJoinChannel(
        (result['room'] ?? '').toString(),
        name,
        false, // never an instructor
        jwt: (result['token'] ?? '').toString(),
        subject: _title,
      );
      _startClosedPoller();
    } catch (e) {
      if (mounted) {
        setState(() {
          _inCall = false;
          _error = 'Could not connect to the session.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_inCall) {
      return Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: SafeArea(
          // The Jitsi host element is registered as a platform view on web.
          // Elsewhere the stub returns an empty id and drives its own webview.
          child: kIsWeb && _videoViewName != null && _videoViewName!.isNotEmpty
              ? SizedBox.expand(
                  child: HtmlElementView(viewType: _videoViewName!))
              : const Center(
                  child: Text('Connecting…',
                      style: TextStyle(color: Colors.white))),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )
                  : _buildCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final invalid = _title.isEmpty && _error != null;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('assets/images/icare_logo.png',
              height: 52,
              errorBuilder: (_, _, _) => const SizedBox(height: 8)),
          const SizedBox(height: 20),
          if (invalid) ...[
            const Icon(Icons.link_off_rounded,
                size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF475569)),
            ),
          ] else ...[
            Text(
              _title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isLive
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isLive ? 'Live now' : 'Not started yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isLive
                        ? const Color(0xFF10B981)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              // Cursor already in the field, and Enter joins: the guest
              // should be able to type a name and be in the session without
              // reaching for the mouse.
              autofocus: true,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _joining ? null : _join(),
              decoration: InputDecoration(
                counterText: '',
                labelText: 'Your name',
                hintText: 'Shown to everyone in the session',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFDC2626)),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _joining ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _joining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.videocam_rounded, size: 20),
                label: Text(_joining ? 'Joining…' : 'Join session'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You are joining as a guest. No account needed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ],
      ),
    );
  }
}
