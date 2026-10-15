import 'package:flutter/material.dart';

import 'api.dart';
import 'checkin_screen.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.loadSession();
  runApp(const BakalGymApp());
}

class BakalGymApp extends StatelessWidget {
  const BakalGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bakal Gym',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD32F2F)),
        useMaterial3: true,
      ),
      home: Api.isLoggedIn ? const CheckInScreen() : const LoginScreen(),
    );
  }
}