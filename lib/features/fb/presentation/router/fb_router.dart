// lib/features/fb/presentation/router/fb_router.dart
import 'package:flutter/material.dart';
import '../pages/fb_dashboard_page.dart';

class FbRouter {
  static const String dashboardPath = '/fb_dashboard';

  static Map<String, WidgetBuilder> get routes => {
    dashboardPath: (context) => const FbDashboardPage(),
  };
}
