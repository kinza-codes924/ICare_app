import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/doctor.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/select_payment_method.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key, required this.doctor});
  final Doctor doctor;

  @override
  ConsumerState<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  final PageController _datePageController = PageController();

  // Date selection
  late List<DateTime> _dateRange;
  int _selectedDateIndex = 0;

  // Time slot selection
  String? _selectedSlot;

  // Step: 0 = slot selection, 1 = reviews, 2 = checkout
  int _step = 0;

  bool _isBooking = false;
  bool _appointmentForMyself = true; // toggle between Myself / Someone else
  bool _isEmergency = false; // emergency booking (outside regular hours)
  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();
  final _genderController = TextEditingController();
  final _ageController = TextEditingController();
  bool _certifyChecked = false; // "I certify all details are correct"
  double? _actualFee; // fetched from doctor profile if not in doctor model

  // Morning slots 9:00 AM - 11:45 AM (15 min intervals)
  List<String> _morningSlots = [
    '09:00 AM', '09:15 AM', '09:30 AM', '09:45 AM',
    '10:00 AM', '10:15 AM', '10:30 AM', '10:45 AM',
    '11:00 AM', '11:15 AM', '11:30 AM', '11:45 AM',
  ];

  // Afternoon slots 12:00 PM - 01:45 PM
  List<String> _afternoonSlots = [
    '12:00 PM', '12:15 PM', '12:30 PM', '12:45 PM',
    '01:00 PM', '01:15 PM', '01:30 PM', '01:45 PM',
  ];

  // Evening slots — generated from doctor's working hours
  List<String> _eveningSlots = [];

  // Dummy reviews
  final List<Map<String, String>> _reviews = [
    {'text': 'Consultation was good', 'patient': 'Verified Patient F', 'ago': '18 days ago'},
    {'text': 'Quickly respond the call and guide properly', 'patient': 'Verified Patient F', 'ago': '19 days ago'},
    {'text': 'I was extremely satisfied with my consultation. The doctor was extremely attentive to listening to my issues and had extremely professional and practical advice.', 'patient': 'Verified Patient U', 'ago': '19 days ago'},
  ];

  @override
  void initState() {
    super.initState();
    // Generate next 8 days starting from today (no past dates)
    final today = DateTime.now();
    _dateRange = List.generate(8, (i) => today.add(Duration(days: i)));
    // Generate slots from doctor's working hours
    _generateSlotsFromDoctorHours();
    // Auto-fill user details for "Myself"
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillMyselfDetails());
    // Fetch actual consultation fee from doctor profile
    _fetchActualFee();
  }

  Future<void> _fetchActualFee() async {
    // If fee already set in doctor model, use it
    if ((widget.doctor.consultationFee ?? 0) > 0) {
      setState(() => _actualFee = widget.doctor.consultationFee);
      return;
    }
    // Otherwise fetch from doctor profile endpoint
    try {
      final doctorId = widget.doctor.user.id.isNotEmpty
          ? widget.doctor.user.id
          : widget.doctor.id;
      if (doctorId.isEmpty) return;
      final response = await DoctorService().getDoctorById(doctorId);
      final doctor = response['doctor'];
      final fee = doctor?['consultationFee'] ?? doctor?['consultation_fee'];
      if (fee != null && (fee is num) && fee > 0 && mounted) {
        setState(() => _actualFee = fee.toDouble());
      }
    } catch (_) {}
  }

  /// Parse time string like "9:00 AM", "09:00 AM", "9:00", "21:00" → TimeOfDay
  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final s = raw.trim().toUpperCase();
      // Format: "9:00 AM" / "09:00 PM"
      final amPmMatch = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(s);
      if (amPmMatch != null) {
        int h = int.parse(amPmMatch.group(1)!);
        final m = int.parse(amPmMatch.group(2)!);
        final isPm = amPmMatch.group(3) == 'PM';
        if (isPm && h != 12) h += 12;
        if (!isPm && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: m);
      }
      // Format: "21:00" / "09:00"
      final h24Match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
      if (h24Match != null) {
        return TimeOfDay(
          hour: int.parse(h24Match.group(1)!),
          minute: int.parse(h24Match.group(2)!),
        );
      }
    } catch (_) {}
    return null;
  }

  void _generateSlotsFromDoctorHours() {
    final avail = widget.doctor.availableTime;
    final startTime = _parseTime(avail?.start) ?? const TimeOfDay(hour: 9, minute: 0);
    final endTime = _parseTime(avail?.end) ?? const TimeOfDay(hour: 22, minute: 0);

    final allSlots = <String>[];
    int h = startTime.hour;
    int m = startTime.minute;

    while (h < endTime.hour || (h == endTime.hour && m < endTime.minute)) {
      final period = h < 12 ? 'AM' : 'PM';
      final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      allSlots.add('${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period');
      m += 15;
      if (m >= 60) { m -= 60; h++; }
    }

    // Split into morning (before 12), afternoon (12-17), evening (17+)
    _morningSlots = allSlots.where((s) {
      final t = _parseTime(s);
      return t != null && t.hour < 12;
    }).toList();

    _afternoonSlots = allSlots.where((s) {
      final t = _parseTime(s);
      return t != null && t.hour >= 12 && t.hour < 17;
    }).toList();

    _eveningSlots = allSlots.where((s) {
      final t = _parseTime(s);
      return t != null && t.hour >= 17;
    }).toList();
  }

  @override
  void dispose() {
    _datePageController.dispose();
    _nameController.dispose();
    _reasonController.dispose();
    _genderController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _fillMyselfDetails() {
    final user = ref.read(authProvider).user;
    if (user != null && _appointmentForMyself) {
      _nameController.text = user.name;
      _genderController.text = user.gender ?? '';
      _ageController.text = user.age ?? '';
    }
  }

  DateTime get _selectedDate => _dateRange[_selectedDateIndex];

  Future<void> _confirmBooking() async {
    if (_selectedSlot == null && !_isEmergency) return;

    // Validate reason
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter Reason for Consultation'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate certification checkbox
    if (!_certifyChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please confirm that all details are correct'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);

    final result = await _appointmentService.bookAppointment(
      doctorId: widget.doctor.id,
      date: _selectedDate,
      timeSlot: _isEmergency ? 'Emergency' : _selectedSlot!,
      reason: _reasonController.text.trim(),
      isEmergency: _isEmergency,
    );

    setState(() => _isBooking = false);
    if (!mounted) return;

    if (result['success']) {
      final fee = _actualFee ?? widget.doctor.consultationFee ?? 0;
      final appointmentId = result['appointment']?.id ?? '';
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectPaymentMethod(
              appointmentId: appointmentId,
              amount: fee.toDouble(),
              onPaymentSuccess: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Booking failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Returns true if a time slot string is in the past for today's date
  bool _isSlotPast(String slot) {
    final selectedDate = _selectedDate;
    final now = DateTime.now();
    // Only check past for today
    if (selectedDate.year != now.year ||
        selectedDate.month != now.month ||
        selectedDate.day != now.day) {
      return false;
    }
    // Parse slot time e.g. "09:00 AM"
    try {
      final parts = slot.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPm = parts[1] == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      final slotTime = DateTime(now.year, now.month, now.day, hour, minute);
      return slotTime.isBefore(now);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primaryColor),
                onPressed: () => setState(() => _step--),
              )
            : const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _step == 2 ? 'Checkout'.tr() : 'Book Appointment'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
      ),
      body: _step == 0
          ? _buildSlotSelection()
          : _step == 1
              ? _buildReviews()
              : _buildCheckout(),
    );
  }

  // ── STEP 0: Date + Slot Selection ─────────────────────────────────────────
  Widget _buildSlotSelection() {
    final fee = _actualFee ?? widget.doctor.consultationFee;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Doctor info card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: (widget.doctor.user.profilePicture != null && widget.doctor.user.profilePicture!.isNotEmpty)
                      ? NetworkImage(widget.doctor.user.profilePicture!)
                      : null,
                  child: (widget.doctor.user.profilePicture == null || widget.doctor.user.profilePicture!.isEmpty)
                      ? Text(
                          widget.doctor.user.name.isNotEmpty ? widget.doctor.user.name.substring(0, 1).toUpperCase() : 'D',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. ${widget.doctor.user.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      Text(widget.doctor.specialization ?? 'General Practitioner',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      if (fee != null && fee > 0)
                        Text('Fee: PKR ${fee.toInt()}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Date strip
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _selectedDateIndex > 0
                      ? () => setState(() => _selectedDateIndex--)
                      : null,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_dateRange.length, (i) {
                        final d = _dateRange[i];
                        final isSelected = i == _selectedDateIndex;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedDateIndex = i;
                            _selectedSlot = null;
                          }),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('MMM').format(d),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Colors.white70 : const Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  DateFormat('dd').format(d),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  DateFormat('EEE').format(d),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Colors.white70 : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _selectedDateIndex < _dateRange.length - 1
                      ? () => setState(() => _selectedDateIndex++)
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Emergency Booking Option (only for doctors with emergency slots)
          if (widget.doctor.emergencySlots) ...[
            GestureDetector(
              onTap: () => setState(() {
                _isEmergency = !_isEmergency;
                if (_isEmergency) _selectedSlot = null;
              }),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isEmergency ? const Color(0xFFDC2626).withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isEmergency ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                    width: _isEmergency ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency Booking'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E))),
                        const SizedBox(height: 2),
                        Text('Book outside regular hours. Doctor will confirm.'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: _isEmergency,
                      onChanged: (v) => setState(() {
                        _isEmergency = v;
                        if (v) _selectedSlot = null;
                      }),
                      activeThumbColor: const Color(0xFFDC2626),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Morning Slots (hidden when emergency mode on)
          if (!_isEmergency) ...[
          _buildSlotSection('Morning Slots'.tr(), Icons.wb_sunny_outlined, _morningSlots),
          const SizedBox(height: 8),

          // Afternoon Slots
          _buildSlotSection('Afternoon Slots'.tr(), Icons.wb_twilight_outlined, _afternoonSlots),
          const SizedBox(height: 8),

          // Evening Slots
          if (_eveningSlots.isNotEmpty) ...[
            _buildSlotSection('Evening Slots'.tr(), Icons.nights_stay_outlined, _eveningSlots),
            const SizedBox(height: 8),
          ],
          ],

          const SizedBox(height: 24),

          // Continue to Book button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_selectedSlot != null || _isEmergency) ? () => setState(() => _step = 1) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Continue to Book'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSlotSection(String title, IconData icon, List<String> slots) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              final isSelected = _selectedSlot == slot;
              final isPast = _isSlotPast(slot);
              return GestureDetector(
                onTap: isPast ? null : () => setState(() => _selectedSlot = slot),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPast
                        ? const Color(0xFFF1F5F9)
                        : isSelected
                            ? AppColors.primaryColor
                            : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPast
                          ? const Color(0xFFE2E8F0)
                          : isSelected
                              ? AppColors.primaryColor
                              : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isPast
                          ? const Color(0xFFCBD5E1)
                          : isSelected
                              ? Colors.white
                              : const Color(0xFF0F172A),
                      decoration: isPast ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── STEP 1: Reviews ────────────────────────────────────────────────────────
  Widget _buildReviews() {
    final reviewCount = widget.doctor.reviewCount;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Trust badge
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFFF59E0B), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('95% patients feel satisfied after booking'.tr(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                      Text('It takes only 30 sec to book an appointment'.tr(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Reviews header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Reviews About Dr. ${widget.doctor.user.name} ($reviewCount)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Review cards
          ..._reviews.map((r) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
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
                    const Icon(Icons.thumb_up_outlined, size: 16, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Text('I recommend the doctor'.tr(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 8),
                Text('" ${r['text']} "',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Text('${r['patient']} • ${r['ago']}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          )),

          const SizedBox(height: 24),

          // Continue to Book button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => setState(() => _step = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Continue to Book'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── STEP 2: Checkout ───────────────────────────────────────────────────────
  Widget _buildCheckout() {
    final fee = _actualFee ?? widget.doctor.consultationFee ?? 0;
    final dateStr = DateFormat('MMM dd').format(_selectedDate);
    final bool isDesktop = Utils.windowWidth(context) > 700;

    final summaryCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor mini card
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  widget.doctor.user.name.isNotEmpty
                      ? widget.doctor.user.name.substring(0, 1).toUpperCase()
                      : 'D',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. ${widget.doctor.user.name}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text(widget.doctor.specialization ?? 'General Practitioner',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Date + time
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('$dateStr, $_selectedSlot',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 8),

          // Consultation type + fee
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Consultation Fee'.tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text(
                fee > 0 ? 'PKR ${fee.toInt()}' : 'Free / As per clinic'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: fee > 0 ? const Color(0xFF0F172A) : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Certification checkbox
          GestureDetector(
            onTap: () => setState(() => _certifyChecked = !_certifyChecked),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _certifyChecked ? AppColors.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _certifyChecked ? AppColors.primaryColor : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: _certifyChecked
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'I certify that all the information I provided is correct.'.tr(),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Booking button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBooking ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _isBooking
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Confirm Booking'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );  // end summaryCard

    final formCard = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Appointment For
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Appointment For'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              Row(
                children: [
                  _forChip('Myself'.tr(), _appointmentForMyself, () {
                    setState(() => _appointmentForMyself = true);
                    _fillMyselfDetails();
                  }),
                  const SizedBox(width: 10),
                  _forChip('+ Someone else'.tr(), !_appointmentForMyself, () {
                    setState(() {
                      _appointmentForMyself = false;
                      _nameController.clear();
                      _genderController.clear();
                      _ageController.clear();
                    });
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // Patient Name
              Text('Patient Name'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                readOnly: _appointmentForMyself,
                decoration: InputDecoration(
                  hintText: 'Enter patient name'.tr(),
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primaryColor)),
                  filled: true,
                  fillColor: _appointmentForMyself ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 12),
              // Gender + Age row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gender'.tr(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _genderController,
                          readOnly: _appointmentForMyself,
                          decoration: InputDecoration(
                            hintText: 'Male / Female'.tr(),
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primaryColor)),
                            filled: true,
                            fillColor: _appointmentForMyself ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Age'.tr(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _ageController,
                          readOnly: _appointmentForMyself,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g. 30'.tr(),
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primaryColor)),
                            filled: true,
                            fillColor: _appointmentForMyself ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Reason for Consultation — MANDATORY
              Row(
                children: [
                  Text('Reason for Consultation'.tr(),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Mandatory'.tr(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe your symptoms or reason for visit...'.tr(),
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primaryColor)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Payment method
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Payment Method'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              // Online Payment option
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.radio_button_checked_rounded, color: AppColors.primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Online Payment'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                    if (fee > 0)
                      Text('PKR ${fee.toInt()}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
              if (fee == 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Consultation fee will be confirmed by the doctor.'.tr(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );  // end formCard

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: formCard),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: summaryCard),
          ],
        ),
      );
    }

    // Mobile: stacked layout
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          summaryCard,
          const SizedBox(height: 16),
          formCard,
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _forChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_rounded, size: 14, color: AppColors.primaryColor),
            if (isSelected) const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primaryColor : const Color(0xFF64748B),
                )),
          ],
        ),
      ),
    );
  }
}
