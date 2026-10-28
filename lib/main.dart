import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/api_config.dart';
import 'core/app_nav.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/bocchi_companion_service.dart';
import 'services/music_player_service.dart';
import 'services/socket_service.dart';
import 'theme/app_theme.dart';
import 'widgets/bocchi_companion_widget.dart';
import 'widgets/dynamic_island_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
  runApp(const SkylineApp());
}

class SkylineApp extends StatelessWidget {
  const SkylineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider(create: (_) => MusicPlayerService()),
        ChangeNotifierProvider(create: (_) => BocchiCompanionService()),
      ],
      child: MaterialApp(
        title: 'VOID SPY',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.light(),
        themeMode: ThemeMode.light,
        home: const LoginScreen(),
        builder: (context, child) {
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const DynamicIslandPlayer(),
              // Bocchi 3D floating companion — available on every page/menu
              const BocchiCompanionWidget(),
            ],
          );
        },
      ),
    );
  }
}
