import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'services/audio_player_service.dart'; // ADD THIS IMPORT
import 'root_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Early UI configuration
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF120F27),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Audio Session setup for version 0.2.x
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint('AudioSession Error: $e');
  }

  // Initialize services early (this triggers discovery)
  AudioPlayerService.instance; // This triggers the singleton initialization

  runApp(const SonixApp());
}

class SonixApp extends StatelessWidget {
  const SonixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()..load()),
      ],
      child: MaterialApp(
        title: 'Sonix',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const RootShell(),
      ),
    );
  }
}