import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/user_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text_input.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Contact 1
  final _name1Controller = TextEditingController();
  final _relation1Controller = TextEditingController();
  final _phone1Controller = TextEditingController();

  // Contact 2
  final _name2Controller = TextEditingController();
  final _relation2Controller = TextEditingController();
  final _phone2Controller = TextEditingController();

  bool _isSaving = false;
  final UserService _userService = UserService();

  @override
  void dispose() {
    _name1Controller.dispose();
    _relation1Controller.dispose();
    _phone1Controller.dispose();
    _name2Controller.dispose();
    _relation2Controller.dispose();
    _phone2Controller.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final contacts = <Map<String, String>>[];
    if (_name1Controller.text.trim().isNotEmpty || _phone1Controller.text.trim().isNotEmpty) {
      contacts.add({
        'name': _name1Controller.text.trim(),
        'relationship': _relation1Controller.text.trim(),
        'phone': _phone1Controller.text.trim(),
      });
    }
    if (_name2Controller.text.trim().isNotEmpty || _phone2Controller.text.trim().isNotEmpty) {
      contacts.add({
        'name': _name2Controller.text.trim(),
        'relationship': _relation2Controller.text.trim(),
        'phone': _phone2Controller.text.trim(),
      });
    }

    final result = await _userService.updateEmergencyContacts(contacts);

    if (mounted) {
      setState(() => _isSaving = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency contacts saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to save contacts'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 700 : double.infinity),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These contacts will be notified in case of a medical emergency.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF991B1B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Contact 1
                  _buildContactSection(
                    number: 1,
                    nameController: _name1Controller,
                    relationController: _relation1Controller,
                    phoneController: _phone1Controller,
                  ),

                  const SizedBox(height: 24),

                  // Contact 2
                  _buildContactSection(
                    number: 2,
                    nameController: _name2Controller,
                    relationController: _relation2Controller,
                    phoneController: _phone2Controller,
                    required: false,
                  ),

                  const SizedBox(height: 36),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Contacts',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactSection({
    required int number,
    required TextEditingController nameController,
    required TextEditingController relationController,
    required TextEditingController phoneController,
    bool required = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.contact_emergency_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Contact $number${required ? '' : ' (Optional)'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CustomInputField(
            hintText: 'Full Name',
            leadingIcon: const Icon(Icons.person_outline, color: Color(0xFF94A3B8)),
            controller: nameController,
            bgColor: const Color(0xFFF8FAFC),
            borderRadius: 12,
            borderColor: const Color(0xFFE2E8F0),
            borderWidth: 1.5,
            validator: required
                ? (val) => (val == null || val.isEmpty) ? 'Please enter a name' : null
                : null,
          ),
          const SizedBox(height: 12),
          CustomInputField(
            hintText: 'Relationship (e.g. Father, Spouse)',
            leadingIcon: const Icon(Icons.family_restroom_rounded, color: Color(0xFF94A3B8)),
            controller: relationController,
            bgColor: const Color(0xFFF8FAFC),
            borderRadius: 12,
            borderColor: const Color(0xFFE2E8F0),
            borderWidth: 1.5,
          ),
          const SizedBox(height: 12),
          CustomInputField(
            hintText: 'Phone Number',
            leadingIcon: const Icon(Icons.phone_outlined, color: Color(0xFF94A3B8)),
            controller: phoneController,
            bgColor: const Color(0xFFF8FAFC),
            borderRadius: 12,
            borderColor: const Color(0xFFE2E8F0),
            borderWidth: 1.5,
            validator: required
                ? (val) => (val == null || val.isEmpty) ? 'Please enter a phone number' : null
                : null,
          ),
        ],
      ),
    );
  }
}
