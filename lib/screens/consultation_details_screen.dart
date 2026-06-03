import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/add_card.dart';
import 'package:icare/screens/connect_now_waiting_screen.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

/// Pre-screen shown before "Connect to Doctor Now" waiting screen.
/// Collects patient details (Myself / Someone else), reason, and certification.
/// After validation → shows Pay Now bottom sheet → then waiting screen.
class ConsultationDetailsScreen extends ConsumerStatefulWidget {
  const ConsultationDetailsScreen({super.key});

  @override
  ConsumerState<ConsultationDetailsScreen> createState() =>
      _ConsultationDetailsScreenState();
}

class _ConsultationDetailsScreenState
    extends ConsumerState<ConsultationDetailsScreen> {
  bool _forMyself = true;
  final _nameController = TextEditingController();
  final _genderController = TextEditingController();
  final _ageController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _certifyChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillMyself());
  }

  void _fillMyself() {
    final user = ref.read(authProvider).user;
    if (user != null && _forMyself) {
      _nameController.text = user.name;
      _genderController.text = user.gender ?? '';
      _ageController.text = user.age ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genderController.dispose();
    _ageController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _proceed() {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter patient name');
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      _showError('Please enter Reason for Consultation');
      return;
    }
    if (!_certifyChecked) {
      _showError('Please confirm that all details are correct');
      return;
    }
    // Show Pay Now popup
    _showPayNowPopup();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Pay Now Bottom Sheet ──────────────────────────────────────────────────
  void _showPayNowPopup() {
    const double amount = 500; // instant consultation fee
    final List<Map<String, String>> savedCards = [
      {'type': 'VISA', 'number': '**** **** **** 1313', 'expiry': '08/26'},
      {'type': 'MasterCard', 'number': '**** **** **** 4242', 'expiry': '12/27'},
    ];
    String? selectedCard = savedCards.first['number'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payment_rounded,
                          color: AppColors.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Pay Now',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('PKR 500',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Existing Payment Methods
                const Text('Existing Payment Method',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B))),
                const SizedBox(height: 12),

                ...savedCards.map((card) {
                  final isSelected = selectedCard == card['number'];
                  return GestureDetector(
                    onTap: () =>
                        setSheet(() => selectedCard = card['number']),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryColor
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(card['type'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(card['number'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: 1)),
                                Text('Expires ${card['expiry']}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primaryColor, size: 20),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // Add new card
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddCard()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: AppColors.primaryColor, size: 20),
                        const SizedBox(width: 10),
                        Text('Add Card Details',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryColor)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Pay & Connect button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx); // close bottom sheet
                      // Navigate to waiting screen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ConnectNowWaitingScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Pay PKR 500 & Connect',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Consultation Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primaryColor.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.video_call_rounded,
                      color: AppColors.primaryColor, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connect to a Doctor Now',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryColor)),
                        Text(
                            'A doctor will connect with you within 3 minutes',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Details card
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
                  const Text('Consultation For',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _chip('Myself', _forMyself, () {
                        setState(() => _forMyself = true);
                        _fillMyself();
                      }),
                      const SizedBox(width: 10),
                      _chip('+ Someone else', !_forMyself, () {
                        setState(() {
                          _forMyself = false;
                          _nameController.clear();
                          _genderController.clear();
                          _ageController.clear();
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _label('Patient Name'),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _nameController,
                    hint: 'Enter patient name',
                    icon: Icons.person_outline_rounded,
                    readOnly: _forMyself,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Gender'),
                            const SizedBox(height: 8),
                            if (_forMyself)
                              // Read-only display for Myself
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _genderController.text.toLowerCase() == 'female'
                                          ? Icons.female_rounded
                                          : _genderController.text.toLowerCase() == 'male'
                                              ? Icons.male_rounded
                                              : Icons.wc_rounded,
                                      size: 16,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _genderController.text.isNotEmpty
                                          ? _genderController.text
                                          : 'Not set in profile',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _genderController.text.isNotEmpty
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              // Editable chips for Someone Else
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: ['Male', 'Female', 'Other']
                                    .map((g) {
                                  final isSelected =
                                      _genderController.text == g;
                                  return GestureDetector(
                                    onTap: () => setState(
                                        () => _genderController.text = g),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primaryColor
                                            : const Color(0xFFF1F5F9),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primaryColor
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        g,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Age'),
                            const SizedBox(height: 8),
                            _textField(
                              controller: _ageController,
                              hint: _forMyself ? 'Not set in profile' : 'e.g. 30',
                              keyboardType: TextInputType.number,
                              readOnly: _forMyself,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reason — Mandatory
                  Row(
                    children: [
                      _label('Reason for Consultation'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Mandatory',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.red)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Describe your symptoms or reason for consultation...',
                      hintStyle:
                          const TextStyle(color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: AppColors.primaryColor)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Certification checkbox — above Pay Now button
            GestureDetector(
              onTap: () =>
                  setState(() => _certifyChecked = !_certifyChecked),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _certifyChecked
                          ? AppColors.primaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _certifyChecked
                            ? AppColors.primaryColor
                            : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                    ),
                    child: _certifyChecked
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'I certify that all the information I provided is correct.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pay Now button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _proceed,
                icon: const Icon(Icons.payment_rounded),
                label: const Text('Pay Now & Connect',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B)),
      );

  Widget _chip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_rounded,
                  size: 14, color: AppColors.primaryColor),
            if (isSelected) const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.primaryColor
                      : const Color(0xFF64748B),
                )),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF94A3B8))
            : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primaryColor)),
        filled: true,
        fillColor:
            readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
      ),
    );
  }
}
