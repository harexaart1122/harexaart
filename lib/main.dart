import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/order_store.dart';
import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    ),
    publishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: '',
    ),
  );

  runApp(const HarexaArtApp());

  // ============================================================
  // SUPABASE ORDER SYNC
  // Jalan setelah aplikasi sudah tampil.
  // Tidak boleh menghambat Login/Auth.
  // ============================================================
  _startOrderSync();
}

Future<void> _startOrderSync() async {
  try {
    await OrderStore.instance.loadFromSupabase();

    OrderStore.instance.startRealtime();

    debugPrint('========================================');
    debugPrint('ORDER SYNC: SUPABASE LOAD + REALTIME BERHASIL');
    debugPrint('========================================');
  } catch (error, stackTrace) {
    debugPrint('========================================');
    debugPrint('ORDER SYNC SUPABASE GAGAL');
    debugPrint('ERROR: $error');
    debugPrint('STACK: $stackTrace');
    debugPrint('========================================');
  }
}

class HarexaArtApp extends StatelessWidget {
  const HarexaArtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HarexaArt',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const LoginPage(),
    );
  }
}