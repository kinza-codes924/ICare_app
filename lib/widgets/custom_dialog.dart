import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'custom_button.dart';

enum DialogStatus { success, error, warning, failed, info }

class CustomDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    DialogStatus? status,
    String? title,
    double? titleSize,
    String? description,
    double? descriptionSize,
    int? descriptionMaxLines,
    Widget? customContent,
    bool showButtons = true,
    bool showCancel = false,
    bool showDone = false,
    bool isDismissible = true,
    String okText = "OK",
    String cancelText = "Cancel",
    String doneText = "Done",
    VoidCallback? onOk,
    VoidCallback? onCancel,
    VoidCallback? onDone,
    Color? backgroundColor,
    double borderRadius = 20,
  }) {
    final statusIcon = _getStatusIcon(status);
    final statusColor = _getStatusColor(status);

    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) {
        return Dialog(
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          backgroundColor: backgroundColor ?? AppColors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.moderateScale(32),
                vertical: ScallingConfig.moderateScale(36),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status Icon
                  if (status != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: SvgWrapper(
                        assetPath: statusIcon,
                        width: ScallingConfig.scale(60),
                        height: ScallingConfig.scale(60),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Custom widget OR title + description
                  if (customContent != null) ...[
                    customContent,
                  ] else ...[
                    if (title != null)
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize:
                              titleSize ?? ScallingConfig.moderateScale(24),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    if (description != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize:
                              descriptionSize ??
                              ScallingConfig.moderateScale(15),
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        maxLines: descriptionMaxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],

                  const SizedBox(height: 36),

                  // Action buttons
                  if (showButtons) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showCancel)
                          Expanded(
                            child: CustomButton(
                              label: cancelText,
                              onPressed: () {
                                Navigator.pop(context);
                                if (onCancel != null) onCancel();
                              },
                              outlined: true,
                            ),
                          ),
                        if (showCancel) const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            label: showDone ? doneText : okText,
                            onPressed: () {
                              Navigator.pop(context);
                              if (showDone && onDone != null) {
                                onDone();
                              } else if (onOk != null) {
                                onOk();
                              }
                            },
                            borderRadius: 16,
                            bgColor: AppColors.primaryColor,
                            height: 54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🔹 Helper — Return appropriate icon for status
  static dynamic _getStatusIcon(DialogStatus? status) {
    switch (status) {
      case DialogStatus.success:
        return ImagePaths.success;
      case DialogStatus.error:
      case DialogStatus.failed:
        return ImagePaths.failed;
      case DialogStatus.warning:
        return ImagePaths.warning;
      // case DialogStatus.info:
      //   return Icons.info_rounded;
      default:
        return ImagePaths.success;
    }
  }

  /// 🔹 Helper — Return color for each status
  static dynamic _getStatusColor(DialogStatus? status) {
    switch (status) {
      case DialogStatus.success:
        return Colors.green;
      case DialogStatus.error:
      case DialogStatus.failed:
        return Colors.red;
      case DialogStatus.warning:
        return Colors.amber;
      case DialogStatus.info:
        return Colors.blue;
      default:
        return Colors.indigo;
    }
  }
}
