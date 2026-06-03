import 'package:flutter/material.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class DoctorAvailability extends StatefulWidget {
  const DoctorAvailability({super.key});

  @override
  State<DoctorAvailability> createState() => _DoctorAvailabilityState();
}

class _DoctorAvailabilityState extends State<DoctorAvailability> {
  final DoctorService _doctorService = DoctorService();

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const List<String> _dayAbbr = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  int _selectedDayIndex = 0;
  Map<String, List<Map<String, String>>> _weeklySlots = {};
  final List<DateTime> _unavailableDates = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = true;
  bool _isSaving = false;
  int _bufferTime = 15;

  bool _is24x7 = false;
  bool _emergencySlots = false;

  // Leave request state
  DateTime? _leaveFrom;
  DateTime? _leaveTo;
  final _leaveReasonCtrl = TextEditingController();
  bool _isSubmittingLeave = false;
  List<Map<String, dynamic>> _leaveRequests = [];

  @override
  void initState() {
    super.initState();
    _initDefaultSlots();
    _loadAvailability();
    _loadLeaveRequests();
  }

  @override
  void dispose() {
    _leaveReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveRequests() async {
    try {
      final result = await _doctorService.getLeaveRequests();
      if (result['success'] == true && mounted) {
        setState(() {
          _leaveRequests = List<Map<String, dynamic>>.from(result['leaveRequests'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _submitLeaveRequest() async {
    if (_leaveFrom == null || _leaveTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both From and To dates.'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSubmittingLeave = true);
    try {
      final result = await _doctorService.requestLeave(
        from: _leaveFrom!,
        to: _leaveTo!,
        reason: _leaveReasonCtrl.text.trim(),
      );
      if (mounted) {
        if (result['success'] == true) {
          final conflicts = result['conflictingAppointments'] ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(conflicts > 0
                ? 'Request submitted. Note: $conflicts appointment(s) exist in this period — admin will review.'
                : 'Leave request submitted. Pending admin approval.'),
            backgroundColor: conflicts > 0 ? Colors.orange : Colors.green,
          ));
          setState(() { _leaveFrom = null; _leaveTo = null; });
          _leaveReasonCtrl.clear();
          _loadLeaveRequests();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message'] ?? 'Failed to submit request.'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong.'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isSubmittingLeave = false);
  }

  void _initDefaultSlots() {
    _weeklySlots = {
      for (final day in _days) day: <Map<String, String>>[]
    };
    // Default Mon-Fri available with one slot each
    for (final day in _days.take(5)) {
      _weeklySlots[day] = [
        {'name': 'Slot 1', 'start': '09:00', 'end': '10:00'}
      ];
    }
  }

  List<String> get _availableDays =>
      _days.where((d) => (_weeklySlots[d]?.isNotEmpty ?? false)).toList();

  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);

    try {
      final result = await _doctorService.getAvailability();

      if (result['success'] && mounted) {
        final availability = result['availability'];

        setState(() {
          final loadedDays = List<String>.from(
            availability['availableDays'] ??
                ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
          );

          // Re-init slots based on loaded available days
          _weeklySlots = {for (final day in _days) day: <Map<String, String>>[]};
          for (final day in loadedDays) {
            _weeklySlots[day] = [
              {'name': 'Slot 1', 'start': '09:00', 'end': '10:00'}
            ];
          }

          final startStr = availability['availableTime']?['start'] ?? '09:00';
          final endStr = availability['availableTime']?['end'] ?? '17:00';
          final startParts = startStr.split(':');
          final endParts = endStr.split(':');
          _startTime = TimeOfDay(
            hour: int.parse(startParts[0]),
            minute: int.parse(startParts[1]),
          );
          _endTime = TimeOfDay(
            hour: int.parse(endParts[0]),
            minute: int.parse(endParts[1]),
          );

          if (availability['unavailableDates'] != null) {
            _unavailableDates.clear();
            for (var dateStr in availability['unavailableDates']) {
              _unavailableDates.add(DateTime.parse(dateStr));
            }
          }

          _bufferTime = availability['bufferTime'] ?? 15;
          _emergencySlots = availability['emergencySlots'] == true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _addUnavailableDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _unavailableDates.add(date));
  }

  void _removeUnavailableDate(DateTime date) {
    setState(() => _unavailableDates.remove(date));
  }

  Future<void> _selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  Future<void> _pickSlotTime(String day, int slotIndex, bool isStart) async {
    final slot = _weeklySlots[day]![slotIndex];
    final parts = (isStart ? slot['start'] : slot['end'])!.split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() {
        final key = isStart ? 'start' : 'end';
        _weeklySlots[day]![slotIndex][key] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _addSlot(String day) {
    final slots = _weeklySlots[day]!;
    if (slots.length >= 3) return;
    setState(() {
      slots.add({
        'name': 'Slot ${slots.length + 1}',
        'start': '09:00',
        'end': '10:00',
      });
    });
  }

  void _removeSlot(String day, int index) {
    setState(() {
      _weeklySlots[day]!.removeAt(index);
      // Renumber
      for (int i = 0; i < _weeklySlots[day]!.length; i++) {
        _weeklySlots[day]![i]['name'] = 'Slot ${i + 1}';
      }
    });
  }

  void _enable24x7() {
    setState(() {
      _is24x7 = true;
      _startTime = const TimeOfDay(hour: 0, minute: 0);
      _endTime = const TimeOfDay(hour: 23, minute: 59);
      // All 7 days with full-day slot
      for (final day in _days) {
        _weeklySlots[day] = [
          {'name': 'Slot 1', 'start': '00:00', 'end': '23:59'}
        ];
      }
    });
  }

  void _disable24x7() {
    setState(() {
      _is24x7 = false;
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
      _initDefaultSlots();
    });
  }

  void _saveAvailability() async {
    setState(() => _isSaving = true);

    final result = await _doctorService.updateAvailability(
      availableDays: _availableDays,
      availableTime: {
        'start': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'end': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      },
      unavailableDates: [],
      bufferTime: _bufferTime,
      emergencySlots: _emergencySlots,
    );

    setState(() => _isSaving = false);

    if (result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability updated successfully')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to update availability')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Manage Availability',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 40 : 20),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 800 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _build24x7Toggle(),
                      const SizedBox(height: 24),
                      _buildWorkingHours(),
                      const SizedBox(height: 24),
                      _buildWeeklySchedule(),
                      const SizedBox(height: 24),
                      _buildPreferences(),
                      const SizedBox(height: 24),
                      _buildEmergencyAppointmentSection(),
                      const SizedBox(height: 24),
                      _buildLeaveRequestSection(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveAvailability,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isSaving ? 'Saving...' : 'Save Availability',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _build24x7Toggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _is24x7
              ? [const Color(0xFF0036BC), const Color(0xFF3B82F6)]
              : [Colors.white, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _is24x7 ? const Color(0xFF0036BC) : const Color(0xFFE2E8F0),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_is24x7 ? const Color(0xFF0036BC) : Colors.black)
                .withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _is24x7
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFF0036BC).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.all_inclusive_rounded,
              color: _is24x7 ? Colors.white : const Color(0xFF0036BC),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '24/7 Available',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _is24x7 ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _is24x7
                      ? 'You are available all day, every day'
                      : 'Enable to be available round the clock',
                  style: TextStyle(
                    fontSize: 13,
                    color: _is24x7
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _is24x7,
            onChanged: (val) => val ? _enable24x7() : _disable24x7(),
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
            inactiveThumbColor: const Color(0xFF0036BC),
            inactiveTrackColor: const Color(0xFF0036BC).withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHours() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Working Hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(true),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start Time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _startTime.format(context),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(false),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'End Time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _endTime.format(context),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySchedule() {
    final currentDay = _days[_selectedDayIndex];
    final slots = _weeklySlots[currentDay] ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.date_range_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Weekly Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Day tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_days.length, (i) {
                final isSelected = i == _selectedDayIndex;
                final hasSlots = (_weeklySlots[_days[i]]?.isNotEmpty ?? false);
                return GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryColor
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryColor
                            : hasSlots
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _dayAbbr[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        if (hasSlots && !isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Slots for selected day
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentDay,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              TextButton.icon(
                onPressed: slots.length < 3 ? () => _addSlot(currentDay) : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(slots.length >= 3 ? 'Max 3 slots' : 'Add Slot'),
                style: TextButton.styleFrom(
                  foregroundColor: slots.length < 3
                      ? AppColors.primaryColor
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (slots.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
              ),
              child: const Center(
                child: Text(
                  'No slots — tap "Add Slot" to set availability for this day',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...slots.asMap().entries.map((entry) {
              final i = entry.key;
              final slot = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        slot['name'] ?? 'Slot ${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  _pickSlotTime(currentDay, i, true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        slot['start'] ?? '09:00',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('–',
                                style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w700)),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  _pickSlotTime(currentDay, i, false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        slot['end'] ?? '10:00',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _removeSlot(currentDay, i),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Color(0xFFEF4444), size: 16),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPreferences() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.settings_suggest_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Scheduling Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buffer Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Minutes between appointments',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              DropdownButton<int>(
                value: _bufferTime,
                items: [0, 5, 10, 15, 20, 30]
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text('$m mins')))
                    .toList(),
                onChanged: (val) => setState(() => _bufferTime = val ?? 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableDates() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_busy_rounded,
                      color: Color(0xFFEF4444),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Unavailable Dates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _addUnavailableDate,
                icon: const Icon(Icons.add_circle_rounded),
                color: AppColors.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_unavailableDates.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No unavailable dates marked',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _unavailableDates.map((date) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(date),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _removeUnavailableDate(date),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmergencyAppointmentSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFEF3C7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emergency_rounded,
              color: Color(0xFFF59E0B),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Appointment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Allow emergency bookings outside regular hours.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _emergencySlots ? 'Enabled — patients can book emergency slots.' : 'Disabled — tap to allow emergency bookings.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Switch(
            value: _emergencySlots,
            onChanged: (v) => setState(() => _emergencySlots = v),
            activeThumbColor: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }

  // ── Schedule Unavailability / Request for Leave ───────────────────────────

  Widget _buildLeaveRequestSection() {
    final fmt = DateFormat('dd MMM yyyy');

    Color statusColor(String s) {
      switch (s) {
        case 'approved': return const Color(0xFF10B981);
        case 'rejected': return const Color(0xFFEF4444);
        default:         return const Color(0xFFF59E0B);
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.event_busy_rounded, color: Color(0xFFB45309), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Schedule Unavailability / Leave', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    Text('Request leave — admin will review & approve.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Date pickers
          Row(
            children: [
              Expanded(child: _datePicker(
                label: 'From Date',
                date: _leaveFrom,
                icon: Icons.calendar_today_rounded,
                color: const Color(0xFF3B82F6),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _leaveFrom = d);
                },
                fmt: fmt,
              )),
              const SizedBox(width: 12),
              Expanded(child: _datePicker(
                label: 'To Date',
                date: _leaveTo,
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _leaveFrom ?? DateTime.now(),
                    firstDate: _leaveFrom ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _leaveTo = d);
                },
                fmt: fmt,
              )),
            ],
          ),
          const SizedBox(height: 14),

          // Reason
          TextField(
            controller: _leaveReasonCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Reason (optional, e.g. Medical conference)',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmittingLeave ? null : _submitLeaveRequest,
              icon: _isSubmittingLeave
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_isSubmittingLeave ? 'Submitting...' : 'Submit Leave Request', style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Past requests
          if (_leaveRequests.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            const Text('My Leave Requests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            ..._leaveRequests.map((req) {
              final from   = DateTime.tryParse(req['fromDate']?.toString() ?? '');
              final to     = DateTime.tryParse(req['toDate']?.toString() ?? '');
              final status = req['status']?.toString() ?? 'pending';
              final reason = req['reason']?.toString() ?? '';
              final conflicts = req['conflictingAppointments'] as int? ?? 0;
              final color  = statusColor(status);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            from != null && to != null
                                ? '${fmt.format(from)}  →  ${fmt.format(to)}'
                                : 'Date range',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(reason, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                          if (conflicts > 0) ...[
                            const SizedBox(height: 2),
                            Text('⚠️ $conflicts conflicting appointment(s)', style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required DateFormat fmt,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: date != null ? color.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: date != null ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: date != null ? color : const Color(0xFF94A3B8), size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: date != null ? color : const Color(0xFF94A3B8))),
            ]),
            const SizedBox(height: 6),
            Text(
              date != null ? fmt.format(date) : 'Select date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: date != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
