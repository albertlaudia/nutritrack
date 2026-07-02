import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/error/app_error_handler.dart';

void main() {
  AppErrorHandler.runGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    AppErrorHandler.install();
    runApp(const ProviderScope(child: NutriTrackApp()));
  });
}