import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/row_text.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: CustomText(
          text: "Product Detail",
          fontFamily: "Gilroy-Bold",
          fontSize: 16.78,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          color: AppColors.primary500,
        ),
        automaticallyImplyLeading: false,
        leading: const CustomBackButton(),
      ),
      body: isDesktop ? _buildWebLayout(context) : _buildMobileLayout(context),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image (Centered & Large)
              Center(
                child: Hero(
                  tag: 'product_image_capsule',
                  child: SizedBox(
                    height: 500,
                    child: Image.asset(ImagePaths.capsule, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 60),

              // Title & Price Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: CustomText(
                      text: "Liver Cleanse Capsule",
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      fontFamily: "Gilroy-Bold",
                      color: AppColors.darkGray300,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(width: 40),
                  CustomText(
                    text: "PKR 2,000",
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Gilroy-Bold",
                    color: AppColors.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quantity
              CustomText(
                text: "250gm",
                fontSize: 20,
                color: AppColors.darkGray600,
                fontFamily: "Gilroy-Medium",
              ),
              const SizedBox(height: 32),

              // Visit Link
              Row(
                children: [
                  CustomText(
                    text: "Visit: ",
                    fontSize: 18,
                    color: AppColors.darkGray500,
                    fontFamily: "Gilroy-Medium",
                  ),
                  CustomText(
                    text: "Pharma",
                    fontSize: 18,
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w800,
                    fontFamily: "Gilroy-Bold",
                    underline: true,
                  ),
                ],
              ),
              const SizedBox(height: 50),

              // Description
              CustomText(
                text:
                    "Our Pharmacy combines advanced diagnostic technology with the expertise of highly qualified professionals, ensuring every test is conducted with precision, accuracy, and reliability to support better healthcare outcomes. Our Pharmacy combines advanced diagnostic technology with the expertise of highly qualified professionals, ensuring every test is conducted with precision, accuracy, and reliability to support better healthcare outcomes.",
                fontSize: 18,
                color: AppColors.grayColor,
                fontFamily: "Gilroy-SemiBold",
                lineHeight: 1.8,
                maxLines: 100,
                overflow: TextOverflow.visible,
              ),
              const SizedBox(height: 50),

              // Precautions Section
              CustomText(
                text: "Precautions",
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: "Gilroy-Bold",
                color: AppColors.darkGray300,
              ),
              const SizedBox(height: 24),
              CustomText(
                text:
                    "Our Pharmacy combines advanced diagnostic technology with the expertise of highly qualified professionals, ensuring every test is conducted with precision, accuracy.",
                fontSize: 18,
                color: AppColors.grayColor,
                fontFamily: "Gilroy-SemiBold",
                lineHeight: 1.8,
                maxLines: 100,
                overflow: TextOverflow.visible,
              ),
              const SizedBox(height: 80),

              // Action Button
              CustomButton(
                label: "Checkout",
                width: double.infinity,
                height: 72,
                borderRadius: 40,
                onPressed: () {},
                labelSize: 20,
                labelWeight: FontWeight.w900,
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Image.asset(ImagePaths.capsule),
          SizedBox(height: ScallingConfig.scale(10)),
          RowText(
            leadingText: "Liver Cleanse Capsule",
            trailingText: "Rs 2000",
            leadingColor: AppColors.darkGray300,
            trailingColor: AppColors.primary500,
            leadingFontSize: 16.78,
            leadingFontFamily: "Gilroy-Bold",
            trailingFontFamily: "Gilroy-Bold",
            trailingFontSize: 16.78,
          ),
          SizedBox(height: ScallingConfig.scale(10)),
          CustomText(
            width: Utils.windowWidth(context) * 0.9,
            color: AppColors.darkGray600,
            fontSize: 10,
            fontFamily: "Gilroy-Regular",
            text: "250gm",
          ),
          SizedBox(height: ScallingConfig.scale(10)),
          SizedBox(
            width: Utils.windowWidth(context) * 0.9,
            child: Row(
              children: [
                CustomText(
                  text: "Visit:",
                  color: AppColors.darkGray500,
                  letterSpacing: -0.6,
                  lineHeight: 1.0,
                ),
                const SizedBox(width: 5),
                CustomText(
                  text: "Pharma",
                  color: AppColors.primaryColor,
                  underline: true,
                  letterSpacing: -0.6,
                  lineHeight: 1.0,
                ),
              ],
            ),
          ),
          SizedBox(height: ScallingConfig.scale(20)),
          CustomText(
            width: Utils.windowWidth(context) * 0.9,
            maxLines: 30,
            color: AppColors.grayColor,
            fontSize: 10.59,
            fontFamily: "Gilroy-SemiBold",
            text:
                "Our Pharmacy combines advanced diagnostic technology with the expertise of highly qualified professionals, ensuring every test is conducted with precision, accuracy, and reliability to support better healthcare outcomes. Our Pharmacy combines advanced diagnostic technology with the expertise of highly qualified professionals, ensuring every test is conducted with precision, accuracy, and reliability to support better healthcare outcomes.",
          ),
          SizedBox(height: ScallingConfig.scale(20)),
          CustomText(
            width: Utils.windowWidth(context) * 0.9,
            color: AppColors.darkGray300,
            fontSize: 16.89,
            fontFamily: "Gilroy-Bold",
            fontWeight: FontWeight.bold,
            text: "Precautions",
          ),
          SizedBox(height: ScallingConfig.scale(20)),
          CustomText(
            width: Utils.windowWidth(context) * 0.9,
            maxLines: 30,
            color: AppColors.grayColor,
            fontSize: 10.59,
            fontFamily: "Gilroy-SemiBold",
            text:
                "Our Pharmacy combines advanced diagnostic technology with the expertise of highly qualified professionals, ensuring every test is conducted with precision, accuracy.",
          ),
          SizedBox(height: ScallingConfig.scale(20)),
          CustomButton(
            label: "Checkout",
            width: Utils.windowWidth(context) * 0.9,
            borderRadius: 40,
            onPressed: () {},
          ),
          SizedBox(height: ScallingConfig.scale(20)),
        ],
      ),
    );
  }
}
