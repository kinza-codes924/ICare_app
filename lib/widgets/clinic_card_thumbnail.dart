import 'package:flutter/material.dart';
import 'package:icare/models/clinic.dart';

// Specialty-relevant thumbnail for a clinic card — the clinic's own
// heroImage (network or local asset) when set, cropped into a small square
// with the specialty icon as a corner badge; falls back to the plain
// icon-square for a clinic without a photo yet. Shared by the homepage
// preview strip and the full 6-clinic grid so both look consistent.
class ClinicCardThumbnail extends StatelessWidget {
  final Clinic clinic;
  const ClinicCardThumbnail({super.key, required this.clinic});

  @override
  Widget build(BuildContext context) {
    final image = clinic.heroImage;
    if (image == null || image.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: clinic.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(clinic.icon, color: clinic.accentColor, size: 26),
      );
    }
    final provider = image.startsWith('http')
        ? NetworkImage(image) as ImageProvider
        : AssetImage(image);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Image(
            image: provider,
            width: double.infinity,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: double.infinity,
              height: 100,
              color: clinic.accentColor.withValues(alpha: 0.12),
              child: Icon(clinic.icon, color: clinic.accentColor, size: 26),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
              ),
              child: Icon(clinic.icon, color: clinic.accentColor, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
