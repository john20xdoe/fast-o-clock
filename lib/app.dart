import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/fasting_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/timeline_screen.dart';
import 'state/fasting_controller.dart';

class FastOClockApp extends StatefulWidget {
  const FastOClockApp({super.key, this.showSplash = true});

  final bool showSplash;

  @override
  State<FastOClockApp> createState() => _FastOClockAppState();
}

class _FastOClockAppState extends State<FastOClockApp> {
  late bool _splashDone = !widget.showSplash;

  TextTheme _buildTextTheme(TextTheme base) {
    final bodyTheme = base.apply(fontFamily: 'Lexend');
    return bodyTheme.copyWith(
      displayLarge: bodyTheme.displayLarge?.copyWith(fontFamily: 'PlusJakartaSans'),
      displayMedium: bodyTheme.displayMedium?.copyWith(fontFamily: 'PlusJakartaSans'),
      displaySmall: bodyTheme.displaySmall?.copyWith(fontFamily: 'PlusJakartaSans'),
      headlineLarge: bodyTheme.headlineLarge?.copyWith(fontFamily: 'PlusJakartaSans'),
      headlineMedium: bodyTheme.headlineMedium?.copyWith(fontFamily: 'PlusJakartaSans'),
      headlineSmall: bodyTheme.headlineSmall?.copyWith(fontFamily: 'PlusJakartaSans'),
      titleLarge: bodyTheme.titleLarge?.copyWith(fontFamily: 'PlusJakartaSans'),
      titleMedium: bodyTheme.titleMedium?.copyWith(fontFamily: 'PlusJakartaSans'),
      titleSmall: bodyTheme.titleSmall?.copyWith(fontFamily: 'PlusJakartaSans'),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF8A00),
      brightness: Brightness.dark,
      surface: const Color(0xFF121417),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Lexend',
      scaffoldBackgroundColor: const Color(0xFF121417),
      cardTheme: const CardThemeData(
        color: Color(0xFF1C1F24),
        elevation: 0,
      ),
    );
    return base.copyWith(textTheme: _buildTextTheme(base.textTheme));
  }

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF8A00),
      brightness: Brightness.light,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Lexend',
      cardTheme: const CardThemeData(
        elevation: 0,
      ),
    );
    return base.copyWith(textTheme: _buildTextTheme(base.textTheme));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FastingController>();
    final Widget home;
    if (!_splashDone) {
      home = SplashScreen(
        onFinished: () => setState(() => _splashDone = true),
      );
    } else if (!controller.isInitialized) {
      home = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (!controller.settings.isOnboarded) {
      home = const OnboardingScreen();
    } else {
      home = const AdaptiveShell();
    }

    return MaterialApp(
      title: "Fast O'Clock",
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: controller.settings.flutterThemeMode,
      home: home,
    );
  }
}

class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    FastingScreen(),
    TimelineScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isExpanded = width >= 600;

    if (isExpanded) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) {
                setState(() {
                  _selectedIndex = idx;
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.timelapse_outlined),
                  selectedIcon: Icon(Icons.timelapse_rounded),
                  label: Text('Fasting'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.timeline_outlined),
                  selectedIcon: Icon(Icons.timeline_rounded),
                  label: Text('Timeline'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pages[_selectedIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _selectedIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timelapse_outlined),
            selectedIcon: Icon(Icons.timelapse_rounded),
            label: 'Fasting',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline_rounded),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
