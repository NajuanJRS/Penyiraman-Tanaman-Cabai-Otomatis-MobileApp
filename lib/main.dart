import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/dashboard_page.dart';
import 'pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions
            .currentPlatform,
  );

  runApp(const MyApp());
}

Future<bool> isLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();

  final token = prefs.getString("token");

  final loginTime = prefs.getInt("login_time");

  if (token == null || loginTime == null) {
    return false;
  }

  final loginDate = DateTime.fromMillisecondsSinceEpoch(loginTime);

  final now = DateTime.now();

  final difference = now.difference(loginDate);

  if (difference.inDays >= 7) {
    await prefs.clear();

    return false;
  }

  return true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Smart Irrigation',

      theme: ThemeData(
        useMaterial3: true,

        scaffoldBackgroundColor: AppColors.background,

        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),

        appBarTheme: const AppBarTheme(backgroundColor: AppColors.background),

        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black26,
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          height: 62,
          indicatorColor: AppColors.lightGreen,

          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
              );
            }

            return const TextStyle(fontSize: 12, color: Colors.grey);
          }),

          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                size: 22,
                color: AppColors.primaryGreen,
              );
            }

            return const IconThemeData(size: 22, color: Colors.grey);
          }),
        ),
      ),

      home: FutureBuilder<bool>(
        future: isLoggedIn(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return snapshot.data! ? const DashboardPage() : const LoginPage();
        },
      ),
    );
  }
}
