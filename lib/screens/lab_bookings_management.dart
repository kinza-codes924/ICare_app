import 'dart:async';
import 'package:flutter/material.dart';
import '../services/laboratory_service.dart';
import '../widgets/back_button.dart';
import 'package:intl/intl.dart';
import 'package:icare/screens/lab_booking_details.dart';
import 'package:icare/utils/error_handler.dart';
import 'package:icare/screens/lab_result_entry_screen.dart';

class LabBookingsManagement extends StatefulWidget {
  final String? initialFilter;
  final String? title;
  const LabBookingsManagement({super.key, this.initialFilter, this.title});

  @override
  State<LabBookingsManagement> createState() => _LabBookingsManagementState();
}

class _LabBookingsManagementState extends State<LabBookingsManagement>
    with TickerProviderStateMixin {
  final LaboratoryService _labService = LaboratoryService();
  Timer? _refreshTimer;
  bool _isLoading = true;
  List<dynamic> _bookings = [];
  String? _labId;
  late String _selectedFilter;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Premium Theme Colors
  static const Color primaryColor = Color(0xFF0B2D6E);
  static const Color secondaryColor = Color(0xFF1565C0);
  static const Color accentColor = Color(0xFF0EA5E9);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'all';
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadBookings();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isLoading) {
        _silentLoadBookings();
      }
    });
  }

  Future<void> _silentLoadBookings() async {
    try {
      if (_labId == null) {
        final profile = await _labService.getProfile();
        _labId = profile['_id'];
      }

      final currentFilter = _selectedFilter;
      final backendStatus = (currentFilter == 'all' || currentFilter == 'urgent')
          ? null
          : currentFilter;
      final bookings = await _labService.getBookings(
        _labId!,
        status: backendStatus,
      );

      if (mounted) {
        setState(() {
          _bookings = bookings;
        });
      }
    } catch (e) {
      debugPrint('Silent refresh error: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);

    try {
      // Only fetch profile once; reuse cached _labId on filter changes
      if (_labId == null) {
        final profile = await _labService.getProfile();
        _labId = profile['_id'];
        if (_labId == null) throw Exception('Laboratory ID not found');
      }

      final currentFilter = _selectedFilter;
      // urgent is a flag not a status — fetch all and filter client-side
      // pending should also include 'accepted' walk-in orders
      final backendStatus = (currentFilter == 'all' || currentFilter == 'urgent')
          ? null
          : currentFilter;
      final bookings = await _labService.getBookings(
        _labId!,
        status: backendStatus,
      );

      // Sort newest first across all filters
      bookings.sort((a, b) {
        final dateA = DateTime.tryParse(a['createdAt'] ?? a['date'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['createdAt'] ?? b['date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showSnackBar(context, e, onRetry: _loadBookings);
      }
    }
  }

  Future<void> _updateStatus(String bookingId, String newStatus) async {
    // If cancelling, require a reason
    if (newStatus == 'cancelled') {
      final reasonCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for cancellation (required):',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter cancellation reason...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Reason is required'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Cancel Booking'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await _labService.updateBookingStatus(bookingId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (newStatus == 'completed') {
          final patientName = _bookings.firstWhere(
            (b) => b['_id'] == bookingId,
            orElse: () => <String, dynamic>{},
          )['patient']?['name']?.toString() ?? 'Patient';
          await _showRatePatientDialog(bookingId, patientName);
        }
      }
      _loadBookings();
    } catch (e) {
      if (mounted) {
        final errorMessage = ErrorHandler.getFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: ErrorHandler.isRetryable(e)
                ? SnackBarAction(
                    label: ErrorHandler.getActionText(e),
                    textColor: Colors.white,
                    onPressed: () => _updateStatus(bookingId, newStatus),
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> _showRatePatientDialog(String bookingId, String patientName) async {
    double rating = 0;
    final commentCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 10),
            Text('Rate Patient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('How was your experience with $patientName?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
                onTap: () => setSt(() => rating = i + 1.0),
                child: Icon(rating > i ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF59E0B), size: 40),
              ))),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
            ElevatedButton(
              onPressed: (submitting || rating == 0) ? null : () async {
                setSt(() => submitting = true);
                try {
                  await _labService.submitBookingRating(bookingId, rating.toInt(), commentCtrl.text.trim());
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Patient rated successfully!'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
    commentCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          widget.title ?? 'Bookings Management',
          style: const TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderDialog(context),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Create Order',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : _bookings.isEmpty
                ? _buildEmptyState()
                : _buildBookingsList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateOrderDialog(BuildContext context) async {
    // Pre-load available tests and collectors from profile
    List<Map<String, dynamic>> availableTests = [];
    List<Map<String, dynamic>> availableCollectors = [];
    try {
      final profile = await _labService.getProfile();
      availableTests = List<Map<String, dynamic>>.from(profile['availableTests'] ?? []);
      availableCollectors = List<Map<String, dynamic>>.from(profile['collectors'] ?? []);
    } catch (_) {}
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final contactController = TextEditingController();
    final locationController = TextEditingController();
    final mrNumberController = TextEditingController();
    final prescriptionDateController = TextEditingController();
    final referredByController = TextEditingController();
    final specimenControllers = <TextEditingController>[TextEditingController()];
    String collectionType = 'in-lab';
    String gender = 'Male';
    bool isUrgent = false;
    String normalTurnaround = '1 Day';
    String urgentTurnaround = '4 Hours';
    bool isSubmitting = false;
    String? selectedTest; // For registered tests dropdown
    String? selectedCollector; // For sample collector dropdown
    final testController = TextEditingController(); // fallback if no tests registered

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_circle_rounded, color: primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Create Walk-in Order',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Patient Details
                  _buildSectionLabel('Patient Details'),
                  const SizedBox(height: 12),
                  _buildFormField(
                    controller: nameController,
                    label: 'Patient Name',
                    icon: Icons.person_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          controller: ageController,
                          label: 'Age',
                          icon: Icons.cake_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gender', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: gender,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.wc_rounded, size: 18, color: primaryColor),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                              ),
                              items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                              onChanged: (v) => setModalState(() => gender = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFormField(
                    controller: mrNumberController,
                    label: 'MR Number (Medical Record Number)',
                    icon: Icons.badge_rounded,
                    hint: 'Permanent patient ID',
                  ),
                  const SizedBox(height: 12),
                  _buildFormField(
                    controller: contactController,
                    label: 'Contact Number',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildFormField(
                    controller: locationController,
                    label: 'Address',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 20),
                  // Referred By
                  _buildSectionLabel('Referred By'),
                  const SizedBox(height: 12),
                  _buildFormField(
                    controller: referredByController,
                    label: 'Referring Doctor Name',
                    icon: Icons.medical_services_rounded,
                    hint: 'Doctor who referred this test',
                  ),
                  const SizedBox(height: 12),
                  _buildFormField(
                    controller: prescriptionDateController,
                    label: 'Test Prescription Date',
                    icon: Icons.calendar_today_rounded,
                    hint: 'DD/MM/YYYY',
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 20),
                  // Tests Required
                  _buildSectionLabel('Test(s) Required'),
                  const SizedBox(height: 12),
                  if (availableTests.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Test', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: selectedTest,
                          hint: const Text('Choose from registered tests'),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.science_rounded, size: 18, color: primaryColor),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          validator: (v) => v == null ? 'Required' : null,
                          items: availableTests.map((t) => DropdownMenuItem<String>(
                            value: t['name']?.toString() ?? '',
                            child: Text(t['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setModalState(() => selectedTest = v),
                        ),
                      ],
                    ),
                  ] else ...[
                    _buildFormField(
                      controller: testController,
                      label: 'Test Name(s)',
                      icon: Icons.science_rounded,
                      hint: 'e.g. CBC, Blood Sugar, Lipid Profile',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFED7AA))),
                      child: const Row(children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFEA580C)),
                        SizedBox(width: 6),
                        Expanded(child: Text('Add tests in Test Management to enable dropdown selection', style: TextStyle(fontSize: 11, color: Color(0xFFEA580C)))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Specimen Information
                  _buildSectionLabel('Specimen Information'),
                  const SizedBox(height: 12),
                  ...specimenControllers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final ctrl = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              controller: ctrl,
                              label: 'Specimen ID ${specimenControllers.length > 1 ? '#${i + 1}' : ''}',
                              icon: Icons.qr_code_rounded,
                              hint: 'Unique ID on test tube/container',
                            ),
                          ),
                          if (specimenControllers.length > 1) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => setModalState(() => specimenControllers.removeAt(i)),
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setModalState(() => specimenControllers.add(TextEditingController())),
                    icon: const Icon(Icons.add_circle_rounded, size: 18),
                    label: const Text('Add Another Specimen'),
                    style: TextButton.styleFrom(foregroundColor: primaryColor),
                  ),
                  if (availableCollectors.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionLabel('Sample Collector'),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assigned Collector', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: selectedCollector,
                          hint: const Text('Select sample collector'),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_pin_rounded, size: 18, color: primaryColor),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          items: availableCollectors.map((c) => DropdownMenuItem<String>(
                            value: c['name']?.toString() ?? '',
                            child: Text('${c['name'] ?? ''} — ${c['designation'] ?? ''}', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setModalState(() => selectedCollector = v),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Collection Type
                  _buildSectionLabel('Collection Type'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCollectionOption(
                          label: 'In-Lab',
                          icon: Icons.business_rounded,
                          value: 'in-lab',
                          selected: collectionType,
                          onTap: () => setModalState(() => collectionType = 'in-lab'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCollectionOption(
                          label: 'Home Collection',
                          icon: Icons.home_rounded,
                          value: 'home',
                          selected: collectionType,
                          onTap: () => setModalState(() => collectionType = 'home'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Urgency & Turnaround
                  _buildSectionLabel('Urgency & Turnaround Time'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Is this test urgent?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      Switch(
                        value: isUrgent,
                        activeThumbColor: const Color(0xFFFF4D00),
                        onChanged: (v) => setModalState(() => isUrgent = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Normal Turnaround', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: normalTurnaround,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                              ),
                              items: ['2 Hours', '4 Hours', '6 Hours', '12 Hours', '1 Day', '2 Days', '3 Days', '4 Days', '5 Days', '7 Days']
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setModalState(() => normalTurnaround = v!),
                            ),
                          ],
                        ),
                      ),
                      if (isUrgent) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Urgent Turnaround', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF4D00))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: urgentTurnaround,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFFF4D00).withValues(alpha: 0.5))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFFF4D00).withValues(alpha: 0.5))),
                                  filled: true,
                                  fillColor: const Color(0xFFFFF5F0),
                                ),
                                items: ['1 Hour', '2 Hours', '4 Hours', '6 Hours', '12 Hours', '24 Hours']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Color(0xFFFF4D00))))).toList(),
                                onChanged: (v) => setModalState(() => urgentTurnaround = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSubmitting = true);
                              try {
                                await _labService.createWalkInOrder(
                                  patientName: nameController.text.trim(),
                                  contact: contactController.text.trim(),
                                  address: locationController.text.trim(),
                                  tests: selectedTest ?? testController.text.trim(),
                                  collectionType: collectionType,
                                  isUrgent: isUrgent,
                                  turnaroundTime: isUrgent ? urgentTurnaround : normalTurnaround,
                                  age: ageController.text.trim(),
                                  gender: gender,
                                  mrNumber: mrNumberController.text.trim(),
                                  referredBy: referredByController.text.trim(),
                                  prescriptionDate: prescriptionDateController.text.trim(),
                                  specimenIds: specimenControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
                                  sampleCollectedBy: selectedCollector,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadBookings();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Walk-in order created successfully'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString()),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Create Order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFamily: 'Gilroy-Bold')),
      ],
    );
  }

  Widget _buildCollectionOption({
    required String label,
    required IconData icon,
    required String value,
    required String selected,
    required VoidCallback onTap,
  }) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF64748B), size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lab Bookings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage and track all test bookings',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.science_rounded, size: 48, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', 'all', Icons.list_rounded),
          _buildFilterChip('Urgent', 'urgent', Icons.priority_high_rounded),
          _buildFilterChip('Pending', 'pending', Icons.schedule_rounded),
          _buildFilterChip(
            'Accepted',
            'confirmed',
            Icons.check_circle_outline_rounded,
          ),
          _buildFilterChip('Sample Collected', 'sample_collected', Icons.science_outlined),
          _buildFilterChip('Awaiting Reports', 'awaiting_reports', Icons.hourglass_empty_rounded),
          _buildFilterChip('Reporting Done', 'reporting_done', Icons.assignment_turned_in_rounded),
          _buildFilterChip('Completed', 'completed', Icons.done_all_rounded),
          _buildFilterChip('Cancelled', 'cancelled', Icons.cancel_outlined),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    final color = _getStatusColor(value);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: () {
          setState(() => _selectedFilter = value);
          _loadBookings();
        },
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
        label: Text(label),
        backgroundColor: isSelected ? color : Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No bookings found',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    // Client-side filtering
    List<dynamic> filteredBookings;
    if (_selectedFilter == 'urgent') {
      // Urgent = is_urgent flag OR urgency == 'Urgent'
      filteredBookings = _bookings.where((b) =>
          b['urgency'] == 'Urgent' ||
          b['is_urgent'] == true ||
          b['isUrgent'] == true ||
          b['priority'] == 'urgent').toList();
    } else if (_selectedFilter == 'pending') {
      // Pending includes 'pending' and 'accepted' (walk-in orders start as accepted)
      filteredBookings = _bookings.where((b) {
        final s = (b['status'] ?? '').toString().toLowerCase();
        return s == 'pending' || s == 'accepted';
      }).toList();
    } else {
      filteredBookings = _bookings;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadBookings,
        child: filteredBookings.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filteredBookings.length,
                itemBuilder: (context, index) =>
                    _buildBookingCard(filteredBookings[index]),
              ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final date = DateTime.tryParse(booking['date'] ?? booking['test_date'] ?? booking['createdAt'] ?? '') ?? DateTime.now();
    final patientName = booking['patient_name'] ?? booking['patient']?['name'] ?? 'Patient';
    final patientAge = booking['patient_age']?.toString() ?? '';
    final patientGender = booking['patient_gender']?.toString() ?? '';
    final patientPhone = booking['patient_phone']?.toString() ?? booking['patient_email']?.toString() ?? '';
    final patientAddress = booking['patient_address']?.toString() ?? '';
    final bookingNumber = booking['_id']?.toString().substring(0, 8).toUpperCase() ?? '';
    final testName = booking['test_type'] ?? booking['testName'] ?? 'Test';
    final isDoctorOrdered = booking['medicalRecord'] != null;
    final doctorName = booking['doctor']?['name'];
    final urgency = booking['urgency'] ?? 'Normal';
    final isUrgent = urgency == 'Urgent' || 
        booking['is_urgent'] == true || 
        booking['isUrgent'] == true ||
        booking['priority'] == 'urgent';
    final diagnosisNotes = booking['diagnosisNotes'];
    final specialInstructions = booking['specialInstructions'];
    final collectionType = booking['collectionType'] ?? booking['collection_type'] ?? 'in-lab';
    final isHomeCollection = collectionType == 'home';

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => LabBookingDetails(booking: booking),
          ),
        );
        _loadBookings();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUrgent
                ? Colors.red.withValues(alpha: 0.4)
                : isDoctorOrdered
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            width: isUrgent || isDoctorOrdered ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Urgency, Doctor-ordered, and Collection Type badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.priority_high_rounded, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text('URGENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.red)),
                      ],
                    ),
                  ),
                if (isDoctorOrdered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.medical_services_rounded, size: 14, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 6),
                        Text(
                          'Ordered by${doctorName != null ? ' Dr. $doctorName' : ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)),
                        ),
                      ],
                    ),
                  ),
                // Sample Collection Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHomeCollection
                        ? const Color(0xFF0EA5E9).withValues(alpha: 0.1)
                        : const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isHomeCollection ? Icons.home_rounded : Icons.business_rounded,
                        size: 14,
                        color: isHomeCollection ? const Color(0xFF0EA5E9) : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isHomeCollection ? 'Home Collection' : 'In Lab',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isHomeCollection ? const Color(0xFF0EA5E9) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getTestIcon(testName), color: statusColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        patientName,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // ── Patient Details ────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Patient Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _detailChip(Icons.person_rounded, 'Name', patientName),
                      if (bookingNumber.isNotEmpty)
                        _detailChip(Icons.tag_rounded, 'MR#', bookingNumber),
                      if (patientAge.isNotEmpty)
                        _detailChip(Icons.cake_rounded, 'Age', patientAge),
                      if (patientGender.isNotEmpty)
                        _detailChip(Icons.wc_rounded, 'Gender', patientGender),
                      if (patientPhone.isNotEmpty)
                        _detailChip(Icons.phone_rounded, 'Phone', patientPhone),
                      if (patientAddress.isNotEmpty)
                        _detailChip(Icons.location_on_rounded, 'Address', patientAddress),
                    ],
                  ),
                ],
              ),
            ),
            // Diagnosis notes
            if (diagnosisNotes != null && diagnosisNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Diagnosis Notes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      diagnosisNotes,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Special instructions
            if (specialInstructions != null &&
                specialInstructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Special Instructions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      specialInstructions,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy').format(date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  'PKR ${_calcPrice(booking)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
            if (['pending', 'confirmed', 'accepted'].contains(status.toLowerCase())) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 15, color: Color(0xFFEA580C)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment must be received before sample collection',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (status.toLowerCase() == 'pending')
                  TextButton.icon(
                    onPressed: () => _updateStatus(booking['_id'], 'confirmed'),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Accept'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                if (status.toLowerCase() == 'pending')
                  TextButton.icon(
                    onPressed: () => _updateStatus(booking['_id'], 'cancelled'),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Decline'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                if (status.toLowerCase() == 'confirmed' ||
                    status.toLowerCase() == 'accepted')
                  TextButton.icon(
                    onPressed: () => _updateStatus(booking['_id'], 'sample_collected'),
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('Sample Collected'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                if (status.toLowerCase() == 'sample_collected' ||
                    status.toLowerCase() == 'sample-collected')
                  TextButton.icon(
                    onPressed: () => _updateStatus(booking['_id'], 'awaiting_reports'),
                    icon: const Icon(Icons.hourglass_empty_rounded, size: 18),
                    label: const Text('Mark Awaiting Reports'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                if (status.toLowerCase() == 'sample_collected' ||
                    status.toLowerCase() == 'sample-collected' ||
                    status.toLowerCase() == 'awaiting_reports' ||
                    status.toLowerCase() == 'awaiting-reports' ||
                    status.toLowerCase() == 'completed')
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => LabResultEntryScreen(booking: booking),
                        ),
                      );
                      _loadBookings();
                    },
                    icon: const Icon(Icons.biotech_rounded, size: 18),
                    label: const Text('Enter Results'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                if (status.toLowerCase() == 'reporting_done' ||
                    status.toLowerCase() == 'reporting-done')
                  TextButton.icon(
                    onPressed: () => _updateStatus(booking['_id'], 'completed'),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Mark Completed'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTestIcon(String testName) {
    final name = testName.toLowerCase();
    if (name.contains('blood')) return Icons.bloodtype_rounded;
    if (name.contains('covid')) return Icons.coronavirus_rounded;
    return Icons.science_rounded;
  }

  /// Calculate price from booking: use saved price if > 0,
  /// otherwise count tests in test_type string × Rs. 3000
  int _calcPrice(Map<String, dynamic> booking) {
    final saved = booking['price'];
    if (saved != null && saved is num && saved > 0) return saved.toInt();
    // Fallback: count comma-separated tests
    final testType = booking['test_type']?.toString() ?? '';
    if (testType.isEmpty) return 0;
    final count = testType.split(',').where((t) => t.trim().isNotEmpty).length;
    return count * 3000;
  }

  Widget _detailChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase().replaceAll('-', '_')) {
      case 'urgent':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'accepted':
        return Colors.green;
      case 'sample_collected':
        return Colors.blue;
      case 'awaiting_reports':
        return const Color(0xFF8B5CF6);
      case 'reporting_done':
        return const Color(0xFF10B981);
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase().replaceAll('-', '_')) {
      case 'pending': return 'PENDING';
      case 'confirmed':
      case 'accepted': return 'ACCEPTED';
      case 'sample_collected': return 'SAMPLE COLLECTED';
      case 'awaiting_reports': return 'AWAITING REPORTS';
      case 'reporting_done': return 'REPORTING DONE';
      case 'completed': return 'COMPLETED';
      case 'cancelled': return 'CANCELLED';
      case 'declined': return 'DECLINED';
      default: return status.toUpperCase().replaceAll('_', ' ');
    }
  }
}
