import 'package:flutter/material.dart';

/// Global navigator key passed to GoRouter.
/// Use this to show dialogs or navigate from contexts that have no Navigator ancestor.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
