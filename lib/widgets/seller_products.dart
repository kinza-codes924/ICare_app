import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/product_details.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_circle_icon_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/section_header.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class SellerProducts extends StatelessWidget {
  const SellerProducts({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) ...[
          SectionHeader(
            title: "Best Seller Products",
            padding: EdgeInsets.symmetric(horizontal: ScallingConfig.scale(10)),
          ),
        ],
        GridView.builder(
          itemCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: isDesktop
              ? const EdgeInsets.all(0)
              : const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 5 : 2,
            mainAxisExtent: isDesktop
                ? 475
                : Utils.windowHeight(context) *
                      0.27, // Increased to clear final overflow
            crossAxisSpacing: isDesktop ? 24 : 20,
            mainAxisSpacing: isDesktop ? 24 : 20,
          ),
          itemBuilder: (ctx, i) {
            return ProductCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => ProductDetailsScreen()),
                );
              },
              showAddToCart: true,
            );
          },
        ),
      ],
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    this.showAddToCart = false,
    this.showRemove = false,
    this.onAdd,
    this.onRemove,
    this.onTap,
  });

  final bool showAddToCart;
  final bool showRemove;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;

    if (isDesktop) {
      return _buildWebProductCard(context);
    }

    return SizedBox(
      width: double.infinity,
      height: Utils.windowHeight(context) * 0.25,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(10),
              ),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    blurStyle: BlurStyle.inner,
                    spreadRadius: 5,
                    blurRadius: 7,
                    color: AppColors.lightGrey200.withAlpha(90),
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(height: ScallingConfig.verticalScale(10)),
                  Image.asset(
                    ImagePaths.capsule,
                    width: double.infinity,
                    height: ScallingConfig.scale(120),
                  ),
                  CustomText(
                    width: double.infinity,
                    text: "Liver Cleanse Capsule",
                    fontFamily: "Gilroy-SemiBold",
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: AppColors.primary500,
                    lineHeight: 1.0,
                    letterSpacing: -0.3,
                  ),
                  SizedBox(height: ScallingConfig.verticalScale(5)),
                  Row(
                    children: [
                      CustomText(
                        text: "Visit:",
                        color: AppColors.darkGray500,
                        letterSpacing: -0.6,
                        lineHeight: 1.0,
                      ),
                      CustomText(
                        text: "NAN Pharma",
                        color: AppColors.primaryColor,
                        underline: true,
                        letterSpacing: -0.6,
                        lineHeight: 1.0,
                      ),
                    ],
                  ),
                  SizedBox(height: ScallingConfig.verticalScale(5)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const IconText(
                        icon: ImagePaths.star_filled,
                        text: "4.9 (2.75)",
                      ),
                      CustomText(
                        text: "Rs. 2000",
                        fontFamily: "Gilroy-SemiBold",
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.primary500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (showAddToCart)
            Positioned(
              top: ScallingConfig.verticalScale(-5),
              right: ScallingConfig.scale(-10),
              child: CustomCircleIconButton(
                iconPath: ImagePaths.cart,
                bgColor: AppColors.primaryColor,
                onTap: onAdd,
                size: 30,
              ),
            ),
          if (showRemove)
            Positioned(
              top: ScallingConfig.verticalScale(-5),
              right: ScallingConfig.scale(-5),
              child: CustomCircleIconButton(
                iconData: Icons.remove,
                iconColor: AppColors.white,
                bgColor: AppColors.themeRed,
                onTap: onRemove,
                size: 30,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebProductCard(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // High-End Image Presentation
              Expanded(
                flex: 12,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF8FAFD),
                        const Color(0xFFFFFFFF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Hero(
                            tag: 'product_image_${onTap.hashCode}',
                            child: Image.asset(
                              ImagePaths.capsule,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "STOCK READY",
                                style: TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Refined Information
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber[600],
                          ),
                          const SizedBox(width: 4),
                          const CustomText(
                            text: "4.9 (+2.4k)",
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8), // Reduced from 12
                      CustomText(
                        text: "Liver Cleanse Capsule",
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                        lineHeight: 1.2,
                        letterSpacing: -0.5,
                      ),
                      const SizedBox(height: 4), // Reduced from 6
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          CustomText(
                            text: "Premium Pharma",
                            fontSize: 13,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Rs. 2,400",
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              CustomText(
                                text: "Rs. 2,000",
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ],
                          ),
                          if (showAddToCart)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: onAdd,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0F172A),
                                        Color(0xFF334155),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF0F172A,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IconText extends StatelessWidget {
  const IconText({
    super.key,
    this.icon,
    this.text = "",
    this.textColor,
    this.iconColor,
  });

  final dynamic icon;
  final String? text;
  final Color? textColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgWrapper(
          assetPath: icon,
          color: iconColor,
          width: isDesktop ? 14 : null,
          height: isDesktop ? 14 : null,
        ),
        SizedBox(width: ScallingConfig.scale(4)),
        CustomText(
          text: text!,
          fontFamily: "Gilroy-Regular",
          color: AppColors.grayColor,
          fontSize: isDesktop ? 12 : 12,
          lineHeight: 1.0,
          letterSpacing: -0.5,
        ),
      ],
    );
  }
}
