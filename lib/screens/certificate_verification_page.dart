import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

/// Certificate Verification Page
class CertificateVerificationPage extends StatefulWidget {
  final String? initialCode;

  const CertificateVerificationPage({
    super.key,
    this.initialCode,
  });

  @override
  State<CertificateVerificationPage> createState() => _CertificateVerificationPageState();
}

class _CertificateVerificationPageState extends State<CertificateVerificationPage> {
  final LmsService _lms = LmsService();
  final TextEditingController _codeController = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!;
      _verifyCertificate();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCertificate() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter certificate code'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _loading = true;
      _searched = false;
      _result = null;
    });

    try {
      final result = await _lms.verifyCertificate(code);
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
          _searched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = {'valid': false, 'message': 'Verification failed'};
          _loading = false;
          _searched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: const CustomBackButton(color: Colors.white),
        title: const Text(
          'Verify Certificate',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryColor, Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Certificate Verification',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the certificate code to verify authenticity',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Input Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Certificate Code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: 'Enter certificate code',
                      prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _verifyCertificate,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search_rounded),
                    label: Text(_loading ? 'Verifying...' : 'Verify Certificate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Result Section
            if (_searched && _result != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _result!['valid'] == true ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _result!['valid'] == true ? Colors.green.shade200 : Colors.red.shade200,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _result!['valid'] == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 64,
                      color: _result!['valid'] == true ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _result!['valid'] == true ? 'Certificate Valid' : 'Certificate Invalid',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _result!['valid'] == true ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result!['message'] ?? (_result!['valid'] == true ? 'This certificate is authentic' : 'Certificate not found'),
                      style: TextStyle(
                        fontSize: 14,
                        color: _result!['valid'] == true ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_result!['valid'] == true && _result!['certificate'] != null) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildInfoRow('Student', _result!['certificate']['studentName'] ?? 'N/A'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Course', _result!['certificate']['courseName'] ?? 'N/A'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Issued Date', _result!['certificate']['issuedAt'] ?? 'N/A'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Certificate ID', _result!['certificate']['certificateId'] ?? 'N/A'),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
