import 'package:flutter/material.dart';
import 'package:icare/screens/patient_prescriptions.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PatientPrescriptions();
  }
}

// ignore: unused_element
class _PrescriptionsScreenLegacyWeb extends StatelessWidget {
  const _PrescriptionsScreenLegacyWeb();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> prescriptions = [
      {
        "id": "PR-8802",
        "doctor": "Dr. Sarah Johnson",
        "specialty": "General Practitioner",
        "date": "15 Sep 2025",
        "medicines": ["Amoxicillin (500mg)", "Paracetamol", "Vitamin C"],
        "status": "Verified",
        "color": const Color(0xFF10B981),
        "avatar": ImagePaths.user7,
      },
      {
        "id": "PR-8805",
        "doctor": "Dr. James Wilson",
        "specialty": "Cardiologist",
        "date": "18 Sep 2025",
        "medicines": ["Atorvastatin", "Aspirin"],
        "status": "Processing",
        "color": const Color(0xFF6366F1),
        "avatar": ImagePaths.user7,
      },
      {
        "id": "PR-8810",
        "doctor": "Dr. Emily Chen",
        "specialty": "Dermatologist",
        "date": "20 Sep 2025",
        "medicines": ["Retinol Cream", "Histamine blockers"],
        "status": "Expired",
        "color": const Color(0xFFEF4444),
        "avatar": ImagePaths.user7,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 220,
            floating: true,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const CustomBackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor.withValues(alpha: 0.05),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 40, 60, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CustomText(
                        text: "MEDICAL RECORDS",
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryColor,
                        letterSpacing: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: CustomText(
                              text: "E-Prescriptions",
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          _buildWebAction(context),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search and Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 24),
              child: Row(
                children: [
                  _buildFilterChip("All Records", true),
                  const SizedBox(width: 12),
                  _buildFilterChip("Verified", false),
                  const SizedBox(width: 12),
                  _buildFilterChip("Pending", false),
                  const Spacer(),
                  _buildWebSearchBar(),
                ],
              ),
            ),
          ),

          // Grid of cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(60, 0, 60, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 550,
                mainAxisExtent: 300,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildPrescriptionCard(context, prescriptions[i]),
                childCount: prescriptions.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildWebAction(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text(
        "Upload Prescription",
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 10,
        shadowColor: AppColors.primaryColor.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildWebSearchBar() {
    return Container(
      width: 320,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: "Search doctor or medicine...",
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isActive ? AppColors.primaryColor : const Color(0xFFE2E8F0),
        ),
      ),
      child: CustomText(
        text: label,
        color: isActive ? Colors.white : const Color(0xFF64748B),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPrescriptionCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor info row
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: AssetImage(data['avatar']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: data['doctor'],
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                    CustomText(
                      text: data['specialty'],
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: (data['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomText(
                  text: data['status'],
                  color: data['color'],
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          CustomText(
            text: "Prescribed Medicines:",
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (data['medicines'] as List<String>)
                .map(
                  (med) => Chip(
                    label: Text(
                      med,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: const Color(0xFFF8FAFD),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: CustomText(
                  text: "Issue Date: ${data['date']}",
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text(
                  "Download PDF",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  backgroundColor: AppColors.primaryColor.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
