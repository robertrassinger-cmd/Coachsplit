import 'package:flutter/material.dart';

import 'coachsplit_home.dart';

class CoachSplitApp extends StatelessWidget {
  const CoachSplitApp({super.key});


  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoachSplit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1118),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF67C7FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const CoachSplitHome(),
    );
  }
}

