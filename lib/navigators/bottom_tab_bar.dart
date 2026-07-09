import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/utils/utils.dart';

class BottomTabBar extends ConsumerWidget {
  const BottomTabBar({super.key, required this.tabs, required this.onSelect});
  final List<Widget>? tabs;
  final Function(dynamic value) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        height: Utils.windowHeight(context) * 0.09,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
          boxShadow: [
            BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -2)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: tabs ?? [],
        ),
      ),
    );
  }
}
