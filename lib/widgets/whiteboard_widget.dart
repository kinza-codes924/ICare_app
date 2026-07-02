import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// ── Tool enum ─────────────────────────────────────────────────────────────────
enum WbTool { pen, eraser, line, rect, circle, arrow, text }

// ── Stroke data model ─────────────────────────────────────────────────────────
class WbStroke {
  final String id;
  final WbTool tool;
  final Color color;
  final double width;
  final List<Offset> points; // normalized 0..1 (pen/eraser)
  final Offset? p1;          // normalized start (shapes) / text anchor
  final Offset? p2;          // normalized end (shapes)
  final String? userId;
  final String? text;        // text tool content

  const WbStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.width,
    this.points = const [],
    this.p1,
    this.p2,
    this.userId,
    this.text,
  });

  factory WbStroke.fromJson(Map<String, dynamic> j) {
    final toolName = j['tool']?.toString() ?? 'pen';
    final tool = WbTool.values.firstWhere(
      (t) => t.name == toolName,
      orElse: () => WbTool.pen,
    );
    Color parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return Colors.black;
      final clean = hex.replaceFirst('#', '');
      final val = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
      return val != null ? Color(val) : Colors.black;
    }
    return WbStroke(
      id: j['id']?.toString() ?? const Uuid().v4(),
      tool: tool,
      color: parseColor(j['color']?.toString()),
      width: (j['width'] as num?)?.toDouble() ?? 3.0,
      points: (j['points'] as List? ?? [])
          .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList(),
      p1: j['p1x'] != null
          ? Offset((j['p1x'] as num).toDouble(), (j['p1y'] as num).toDouble())
          : null,
      p2: j['p2x'] != null
          ? Offset((j['p2x'] as num).toDouble(), (j['p2y'] as num).toDouble())
          : null,
      userId: j['userId']?.toString(),
      text: j['text']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final r = (color.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return {
      'id': id,
      'tool': tool.name,
      'color': '#$r$g$b',
      'width': width,
      'points': points.map((p) => [p.dx, p.dy]).toList(),
      if (p1 != null) 'p1x': p1!.dx,
      if (p1 != null) 'p1y': p1!.dy,
      if (p2 != null) 'p2x': p2!.dx,
      if (p2 != null) 'p2y': p2!.dy,
      if (userId != null) 'userId': userId,
      if (text != null) 'text': text,
    };
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────
class _WhiteboardPainter extends CustomPainter {
  final List<WbStroke> strokes;
  final WbStroke? current;

  const _WhiteboardPainter({required this.strokes, this.current});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);
    for (final s in strokes) {
      _paint(canvas, size, s);
    }
    if (current != null) _paint(canvas, size, current!);
  }

  void _paint(Canvas canvas, Size size, WbStroke s) {
    final paint = Paint()
      ..color = s.tool == WbTool.eraser ? Colors.white : s.color
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    Offset d(Offset n) => Offset(n.dx * size.width, n.dy * size.height);

    switch (s.tool) {
      case WbTool.pen:
      case WbTool.eraser:
        if (s.points.isEmpty) return;
        if (s.points.length == 1) {
          canvas.drawCircle(d(s.points.first), s.width / 2,
              Paint()..color = paint.color..style = PaintingStyle.fill);
          return;
        }
        final path = Path()..moveTo(d(s.points.first).dx, d(s.points.first).dy);
        for (int i = 1; i < s.points.length; i++) {
          path.lineTo(d(s.points[i]).dx, d(s.points[i]).dy);
        }
        canvas.drawPath(path, paint);

      case WbTool.line:
        if (s.p1 == null || s.p2 == null) return;
        canvas.drawLine(d(s.p1!), d(s.p2!), paint);

      case WbTool.rect:
        if (s.p1 == null || s.p2 == null) return;
        canvas.drawRect(Rect.fromPoints(d(s.p1!), d(s.p2!)), paint);

      case WbTool.circle:
        if (s.p1 == null || s.p2 == null) return;
        canvas.drawOval(Rect.fromPoints(d(s.p1!), d(s.p2!)), paint);

      case WbTool.arrow:
        if (s.p1 == null || s.p2 == null) return;
        final from = d(s.p1!);
        final to   = d(s.p2!);
        canvas.drawLine(from, to, paint);
        _drawArrowHead(canvas, from, to, paint);

      case WbTool.text:
        if (s.p1 == null || (s.text?.isEmpty ?? true)) return;
        final fontSize = (s.width * 3 + 10).clamp(12.0, 60.0);
        final tp = TextPainter(
          text: TextSpan(
            text: s.text,
            style: TextStyle(color: s.color, fontSize: fontSize, fontWeight: FontWeight.w500),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width - d(s.p1!).dx);
        tp.paint(canvas, d(s.p1!));
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    const headLen = 18.0;
    const headAngle = 0.45; // radians (~26°)
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final p1 = Offset(
      to.dx - headLen * math.cos(angle - headAngle),
      to.dy - headLen * math.sin(angle - headAngle),
    );
    final p2 = Offset(
      to.dx - headLen * math.cos(angle + headAngle),
      to.dy - headLen * math.sin(angle + headAngle),
    );
    canvas.drawLine(to, p1, paint);
    canvas.drawLine(to, p2, paint);
  }

  @override
  bool shouldRepaint(_WhiteboardPainter old) => true;
}

// ── Main Widget ───────────────────────────────────────────────────────────────
class WhiteboardWidget extends StatefulWidget {
  final bool isEditable;
  final List<WbStroke> strokes;
  final String currentUserId;
  final void Function(WbStroke stroke)? onStrokeAdded;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  // Instructor-only: list of attendee names/ids for permission granting
  final List<Map<String, dynamic>> attendees;
  final List<String> permissionedUserIds;
  final void Function(String userId, bool grant)? onPermissionChanged;

  const WhiteboardWidget({
    super.key,
    required this.isEditable,
    required this.strokes,
    required this.currentUserId,
    this.onStrokeAdded,
    this.onUndo,
    this.onClear,
    this.attendees = const [],
    this.permissionedUserIds = const [],
    this.onPermissionChanged,
  });

  @override
  State<WhiteboardWidget> createState() => _WhiteboardWidgetState();
}

class _WhiteboardWidgetState extends State<WhiteboardWidget> {
  WbTool _tool = WbTool.pen;
  Color _color = Colors.black;
  double _width = 3.0;

  WbStroke? _current;
  List<Offset> _penPoints = [];
  Offset? _shapeStart;
  Offset? _shapeEnd;

  Size _canvasSize = Size.zero;

  static const _colors = [
    Colors.black, Colors.red, Colors.blue, Colors.green,
    Color(0xFFF97316), Color(0xFF8B5CF6), Color(0xFFEC4899), Colors.white,
  ];

  static const _widths = [2.0, 4.0, 8.0, 14.0];

  Offset _norm(Offset local) {
    if (_canvasSize == Size.zero) return Offset.zero;
    return Offset(
      (local.dx / _canvasSize.width).clamp(0.0, 1.0),
      (local.dy / _canvasSize.height).clamp(0.0, 1.0),
    );
  }

  void _onPointerDown(Offset local) {
    if (!widget.isEditable) return;
    if (_tool == WbTool.text) {
      _showTextInputDialog(local);
      return;
    }
    setState(() {
      _penPoints = [_norm(local)];
      _shapeStart = _norm(local);
      _shapeEnd = _norm(local);
      _current = null;
    });
  }

  void _showTextInputDialog(Offset tapPosition) {
    final ctrl = TextEditingController();
    final anchor = _norm(tapPosition);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Type something...'),
          onSubmitted: (_) => _submitText(ctx, ctrl, anchor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => _submitText(ctx, ctrl, anchor), child: const Text('Place')),
        ],
      ),
    );
  }

  void _submitText(BuildContext ctx, TextEditingController ctrl, Offset anchor) {
    final v = ctrl.text.trim();
    if (v.isEmpty) return;
    Navigator.pop(ctx);
    final stroke = WbStroke(
      id: const Uuid().v4(),
      tool: WbTool.text,
      color: _color,
      width: _width,
      p1: anchor,
      text: v,
      userId: widget.currentUserId,
    );
    widget.onStrokeAdded?.call(stroke);
  }

  void _onPointerMove(Offset local) {
    if (!widget.isEditable) return;
    final n = _norm(local);
    setState(() {
      if (_tool == WbTool.pen || _tool == WbTool.eraser) {
        _penPoints = [..._penPoints, n];
        _current = WbStroke(
          id: '', tool: _tool, color: _color, width: _width, points: _penPoints,
        );
      } else {
        _shapeEnd = n;
        _current = WbStroke(
          id: '', tool: _tool, color: _color, width: _width,
          p1: _shapeStart, p2: n,
        );
      }
    });
  }

  void _onPointerUp() {
    if (!widget.isEditable || _current == null) return;
    final id = const Uuid().v4();
    final stroke = WbStroke(
      id: id,
      tool: _tool,
      color: _color,
      width: _width,
      points: _penPoints,
      p1: _shapeStart,
      p2: _shapeEnd,
      userId: widget.currentUserId,
    );
    setState(() { _current = null; _penPoints = []; });
    widget.onStrokeAdded?.call(stroke);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Toolbar ──────────────────────────────────────────────────────────
      if (widget.isEditable) _buildToolbar(),
      if (!widget.isEditable)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFFF1F5F9),
          child: Row(children: [
            const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            const Text('View only — instructor controls the whiteboard',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
        ),

      // ── Canvas ───────────────────────────────────────────────────────────
      Expanded(
        child: LayoutBuilder(builder: (ctx, constraints) {
          _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Listener(
            onPointerDown: (e) => _onPointerDown(e.localPosition),
            onPointerMove: (e) => _onPointerMove(e.localPosition),
            onPointerUp:   (_) => _onPointerUp(),
            onPointerCancel: (_) => setState(() { _current = null; _penPoints = []; }),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WhiteboardPainter(strokes: widget.strokes, current: _current),
                size: Size.infinite,
              ),
            ),
          );
        }),
      ),
    ]);
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0B2D6E),
        border: Border(bottom: BorderSide(color: Color(0xFF1E3A8A), width: 1)),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // ── Tools ──────────────────────────────────────────
          _toolBtn(WbTool.pen,    Icons.edit_rounded,          'Pen'),
          _toolBtn(WbTool.eraser, Icons.auto_fix_high_rounded, 'Eraser'),
          _toolBtn(WbTool.line,   Icons.remove_rounded,        'Line'),
          _toolBtn(WbTool.rect,   Icons.crop_square_rounded,   'Rect'),
          _toolBtn(WbTool.circle, Icons.circle_outlined,       'Circle'),
          _toolBtn(WbTool.arrow,  Icons.arrow_forward_rounded, 'Arrow'),
          _toolBtn(WbTool.text,   Icons.text_fields_rounded,   'Text'),

          const _Divider(),

          // ── Colors ─────────────────────────────────────────
          ..._colors.map((c) => _colorSwatch(c)),

          const _Divider(),

          // ── Widths ─────────────────────────────────────────
          ..._widths.map((w) => _widthBtn(w)),

          const _Divider(),

          // ── Actions ────────────────────────────────────────
          _actionBtn(Icons.undo_rounded, 'Undo', widget.onUndo),
          _actionBtn(Icons.delete_outline_rounded, 'Clear', widget.onClear != null
              ? () => _confirmClear()
              : null),

          if (widget.attendees.isNotEmpty)
            _actionBtn(Icons.manage_accounts_rounded, 'Permissions', _showPermissionSheet),
        ],
      ),
    );
  }

  Widget _toolBtn(WbTool t, IconData icon, String tip) {
    final active = _tool == t;
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: () => setState(() => _tool = t),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: active ? Colors.white : Colors.transparent),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _colorSwatch(Color c) {
    final active = _color.toARGB32() == c.toARGB32();
    return GestureDetector(
      onTap: () => setState(() {
        _color = c;
        if (_tool == WbTool.eraser) _tool = WbTool.pen;
      }),
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? Colors.amber : Colors.white.withValues(alpha: 0.4),
            width: active ? 2.5 : 1,
          ),
        ),
      ),
    );
  }

  Widget _widthBtn(double w) {
    final active = _width == w;
    return GestureDetector(
      onTap: () => setState(() => _width = w),
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Container(
          width: (w * 1.8).clamp(3, 18),
          height: (w * 1.8).clamp(3, 18),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String tip, VoidCallback? onTap) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: onTap != null ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
          ),
          child: Icon(icon,
              color: onTap != null ? Colors.white : Colors.white38, size: 18),
        ),
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Whiteboard'),
        content: const Text('Remove all drawings? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(context); widget.onClear?.call(); },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPermissionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PermissionSheet(
        attendees: widget.attendees,
        permissionedIds: widget.permissionedUserIds,
        onChanged: widget.onPermissionChanged,
      ),
    );
  }
}

// ── Permission Sheet ──────────────────────────────────────────────────────────
class _PermissionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> attendees;
  final List<String> permissionedIds;
  final void Function(String userId, bool grant)? onChanged;

  const _PermissionSheet({required this.attendees, required this.permissionedIds, this.onChanged});

  @override
  State<_PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends State<_PermissionSheet> {
  late final Set<String> _granted;

  @override
  void initState() {
    super.initState();
    _granted = Set.from(widget.permissionedIds);
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.attendees.where((a) => a['role'] != 'Instructor').toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Drawing Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Grant students temporary whiteboard access', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 16),
        if (students.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No students in session', style: TextStyle(color: Color(0xFF94A3B8))),
          )
        else
          ...students.map((s) {
            final uid = s['userId']?.toString() ?? s['_id']?.toString() ?? '';
            final name = s['name']?.toString() ?? s['userName']?.toString() ?? 'Student';
            final hasAccess = _granted.contains(uid);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0B2D6E).withValues(alpha: 0.1),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: const TextStyle(color: Color(0xFF0B2D6E), fontWeight: FontWeight.w700)),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Switch(
                value: hasAccess,
                activeThumbColor: const Color(0xFF0B2D6E),
                onChanged: (v) {
                  setState(() {
                    if (v) { _granted.add(uid); } else { _granted.remove(uid); }
                  });
                  widget.onChanged?.call(uid, v);
                },
              ),
            );
          }),
      ]),
    );
  }
}

// ── Small vertical divider for toolbar ───────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 24,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Colors.white.withValues(alpha: 0.25),
  );
}
