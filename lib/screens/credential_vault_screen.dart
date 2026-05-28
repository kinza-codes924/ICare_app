import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:url_launcher/url_launcher.dart';

class CredentialVaultScreen extends StatefulWidget {
  const CredentialVaultScreen({super.key});

  @override
  State<CredentialVaultScreen> createState() => _CredentialVaultScreenState();
}

class _CredentialVaultScreenState extends State<CredentialVaultScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _credentials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCredentials();
  }

  Future<void> _fetchCredentials() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/credentials/me');
      if (mounted) {
        setState(() {
          _credentials = response.data['credentials'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Page-1 JPEG thumbnail — for showing preview inside the modal
  String _cloudinaryPdfThumbnail(String pdfUrl) {
    try {
      return pdfUrl
          .replaceFirst('/raw/upload/', '/image/upload/f_jpg,pg_1/')
          .replaceFirstMapped(
            RegExp(r'/image/upload/(?!f_jpg,pg_1/)'),
            (_) => '/image/upload/f_jpg,pg_1/',
          );
    } catch (_) {
      return pdfUrl;
    }
  }

  /// Ensures Cloudinary PDF URL has no transformation flags that cause 400.
  /// Just returns the clean URL — browsers open PDFs inline by default.
  String _cloudinaryCleanUrl(String url) {
    // Strip any existing flags we may have inserted
    try {
      return url
          .replaceFirst('/fl_inline/', '/')
          .replaceFirst('/fl_attachment/', '/');
    } catch (_) {
      return url;
    }
  }

  /// Opens a URL in a new browser tab using url_launcher.
  Future<void> _openDocUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Cannot open URL: $e');
    }
  }

  /// Downloads via Cloudinary fl_attachment flag so CDN forces Content-Disposition: attachment.
  Future<void> _downloadDocUrl(String url) async {
    if (url.isEmpty) return;
    try {
      String dlUrl = _cloudinaryCleanUrl(url);
      // fl_attachment makes Cloudinary send Content-Disposition: attachment → browser saves the file
      if (dlUrl.contains('cloudinary.com') && dlUrl.contains('/upload/')) {
        dlUrl = dlUrl.replaceFirst('/upload/', '/upload/fl_attachment/');
      }
      final uri = Uri.parse(dlUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      await _openDocUrl(url);
    }
  }

  void _viewDocument(dynamic cred) {
    // documentUrl can be stored under different keys — check both
    final docUrl = (cred['documentUrl'] as String?)?.trim() ??
                   (cred['document_url'] as String?)?.trim() ?? '';
    final title  = cred['title']?.toString() ?? 'Document';
    final type   = cred['type']?.toString() ?? '';

    // PDF check FIRST — a Cloudinary PDF may have /image/upload/ in its path
    // if it was uploaded with wrong resource_type. Extension is the ground truth.
    final isPdf = docUrl.isNotEmpty &&
        RegExp(r'\.pdf(\?.*)?$', caseSensitive: false).hasMatch(docUrl);

    // Image only when NOT a PDF
    final isImage = !isPdf && docUrl.isNotEmpty &&
        RegExp(r'\.(jpg|jpeg|png|gif|webp|svg|png)(\?.*)?$', caseSensitive: false)
            .hasMatch(docUrl);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 750),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    Text(type, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ]),
              ),

              // Document preview
              Expanded(
                child: docUrl.isEmpty
                    // ── No URL stored ─────────────────────────────────────────
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.upload_file_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No document attached to this certificate.', style: TextStyle(color: Color(0xFF94A3B8))),
                        const SizedBox(height: 6),
                        const Text('Upload a new certificate to attach a file.', style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                      ]))
                    // ── Image preview ─────────────────────────────────────────
                    : isImage
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            docUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, prog) => prog == null
                                ? child
                                : const Center(child: CircularProgressIndicator()),
                            errorBuilder: (_, _, _) => _urlFallback(ctx, docUrl),
                          ),
                        ),
                      )
                    // ── PDF — show Cloudinary page-1 thumbnail ────────────────
                    : _buildPdfPreview(ctx, docUrl),
              ),

              // Download button
              // Bottom download button only for images (PDFs have their own buttons above)
              if (docUrl.isNotEmpty && isImage)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () { _openDocUrl(docUrl); Navigator.pop(ctx); },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Open / Download', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Renders page-1 of a Cloudinary PDF as an image, with open/download button
  Widget _buildPdfPreview(BuildContext ctx, String pdfUrl) {
    final thumbUrl = _cloudinaryPdfThumbnail(pdfUrl);
    return Column(
      children: [
        // Page-1 thumbnail
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                thumbUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, prog) => prog == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, _, _) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, size: 64, color: Color(0xFFEF4444)),
                    ),
                    const SizedBox(height: 12),
                    const Text('PDF — tap below to open', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Open in browser tab + Download as .pdf
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                // Open FIRST then close dialog — preserves user-gesture for url_launcher/popup
                onPressed: () { _openDocUrl(_cloudinaryCleanUrl(pdfUrl)); Navigator.pop(ctx); },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  side: BorderSide(color: AppColors.primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                // Download FIRST then close dialog — preserves user-gesture for url_launcher/popup
                onPressed: () { _downloadDocUrl(_cloudinaryCleanUrl(pdfUrl)); Navigator.pop(ctx); },
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }


  // Shown when Image.network fails — still gives user a way to open the file
  Widget _urlFallback(BuildContext ctx, String url) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      const Text('Could not render preview.', style: TextStyle(color: Color(0xFF94A3B8))),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: () { _openDocUrl(url); Navigator.pop(ctx); },
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: const Text('Open in Browser'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }


  // Upload using Dio FormData — same auth headers as all other API calls.
  // package:http MultipartRequest was failing silently because it doesn't
  // share the Dio auth token injection logic.
  Future<String?> _uploadFileToBackend(Uint8List bytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          // Guess content type from extension
          contentType: fileName.toLowerCase().endsWith('.pdf')
              ? DioMediaType('application', 'pdf')
              : DioMediaType('image', 'jpeg'),
        ),
      });
      final response = await _apiService.postMultipart('/upload/prescription', formData);
      debugPrint('Upload response: ${response.data}');
      if (response.data['success'] == true) {
        return response.data['url'] as String?;
      }
      debugPrint('Upload failed: ${response.data}');
      return null;
    } catch (e) {
      debugPrint('Upload exception: $e');
      return null;
    }
  }

  void _showUploadDialog() {
    final titleController = TextEditingController();
    String type = 'Medical License';
    bool isUploading = false;
    String? pickedFileName;
    Uint8List? pickedBytes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upload Credential',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'DOCUMENT TYPE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: type,
                items:
                    [
                          'Medical License',
                          'Specialization Certificate',
                          'Indemnity Insurance',
                          'Other',
                        ]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                onChanged: (v) => type = v!,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'DOCUMENT TITLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. PMC License 2024',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                    withData: true,
                  );
                  if (result != null && result.files.single.bytes != null) {
                    setModalState(() {
                      pickedFileName = result.files.single.name;
                      pickedBytes   = result.files.single.bytes;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: pickedFileName != null ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: pickedFileName != null ? AppColors.primaryColor : AppColors.primaryColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          pickedFileName != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                          color: pickedFileName != null ? Colors.green : AppColors.primaryColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pickedFileName ?? 'Tap to select PDF or Image',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: pickedFileName != null ? AppColors.primaryColor : const Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        pickedFileName != null ? 'Tap to change file' : 'PDF, JPG, PNG  •  Max 10MB',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  label: isUploading
                      ? 'Uploading...'
                      : 'Submit for Verification',
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
                            return;
                          }
                          if (pickedBytes == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a file')));
                            return;
                          }
                          setModalState(() => isUploading = true);
                          try {
                            // Step 1: upload file → get Cloudinary URL
                            final url = await _uploadFileToBackend(
                              pickedBytes!, pickedFileName ?? 'document');
                            if (url == null || url.isEmpty) {
                              setModalState(() => isUploading = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('File upload failed. Check your connection and try again.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              }
                              return;
                            }
                            // Step 2: save credential record with the returned URL
                            await _apiService.post('/credentials', {
                              'type': type,
                              'title': titleController.text.trim(),
                              'documentUrl': url,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            // Small delay so the backend finishes writing before we re-fetch
                            await Future.delayed(const Duration(milliseconds: 400));
                            _fetchCredentials();
                          } catch (e) {
                            setModalState(() => isUploading = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            }
                          }
                        },
                ),
              ),
              const SizedBox(height: 32),
            ],
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
        title: const Text(
          'Certificate',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchCredentials,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildVaultHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _credentials.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _credentials.length,
                    itemBuilder: (ctx, i) =>
                        _buildCredentialCard(_credentials[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        label: const Text(
          'Add Document',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  Widget _buildVaultHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Certificates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your medical licenses and certifications for platform verification.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildVaultStat('Total', '${_credentials.length}', Colors.blue),
              const SizedBox(width: 12),
              _buildVaultStat('Verified', '${_credentials.where((c) => c['status'] == 'verified').length}', Colors.green),
              const SizedBox(width: 12),
              _buildVaultStat('Unverified', '${_credentials.where((c) => c['status'] != 'verified').length}', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVaultStat(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Text(
            count,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Vault is Empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload your license to get verified and start',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const Text(
            'accepting consultation requests.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialCard(dynamic cred) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (cred['status']) {
      case 'verified':
        statusColor = Colors.green;
        statusText = 'VERIFIED';
        statusIcon = Icons.verified_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        statusIcon = Icons.cancel_rounded;
        break;
      case 'expired':
        statusColor = Colors.orange;
        statusText = 'EXPIRED';
        statusIcon = Icons.warning_rounded;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'UNVERIFIED';
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.file_present_rounded,
              color: statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cred['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  cred['type'],
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                // Prominent verified / unverified badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (statusText == 'UNVERIFIED')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pending admin review',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => _viewDocument(cred),
                icon: const Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFF64748B),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                ),
              ),
              const Text(
                'View',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
