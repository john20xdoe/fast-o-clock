import 'package:dynamic_color/dynamic_color.dart';
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
    final bodyTheme = base.apply(fontFamily: 'IBMPlexSans');
    return bodyTheme.copyWith(
      displayLarge: bodyTheme.displayLarge?.copyWith(fontFamily: 'Lexend'),
      displayMedium: bodyTheme.displayMedium?.copyWith(fontFamily: 'Lexend'),
      displaySmall: bodyTheme.displaySmall?.copyWith(fontFamily: 'Lexend'),
      headlineLarge: bodyTheme.headlineLarge?.copyWith(fontFamily: 'Lexend'),
      headlineMedium: bodyTheme.headlineMedium?.copyWith(fontFamily: 'Lexend'),
      headlineSmall: bodyTheme.headlineSmall?.copyWith(fontFamily: 'Lexend'),
      titleLarge: bodyTheme.titleLarge?.copyWith(fontFamily: 'Lexend'),
      titleMedium: bodyTheme.titleMedium?.copyWith(fontFamily: 'Lexend'),
      titleSmall: bodyTheme.titleSmall?.copyWith(fontFamily: 'Lexend'),
      labelLarge: bodyTheme.labelLarge?.copyWith(fontFamily: 'Lexend'),
      labelMedium: bodyTheme.labelMedium?.copyWith(fontFamily: 'Lexend'),
      labelSmall: bodyTheme.labelSmall?.copyWith(fontFamily: 'Lexend'),
    );
  }

  bool _isNonMonochrome(ColorScheme? scheme) {
    if (scheme == null) return false;
    return HSLColor.fromColor(scheme.primary).saturation >= 0.08;
  }

  ThemeData _buildDarkTheme([ColorScheme? dynamicScheme]) {
    final useDynamic = _isNonMonochrome(dynamicScheme);
    final scheme = useDynamic
        ? dynamicScheme!
        : ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF8A00),
            brightness: Brightness.dark,
            surface: const Color(0xFF121417),
          );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'IBMPlexSans',
      scaffoldBackgroundColor:
          useDynamic ? scheme.surface : const Color(0xFF121417),
      cardTheme: CardThemeData(
        color: useDynamic ? null : const Color(0xFF1C1F24),
        elevation: 0,
      ),
    );
    return base.copyWith(textTheme: _buildTextTheme(base.textTheme));
  }

  ThemeData _buildLightTheme([ColorScheme? dynamicScheme]) {
    final useDynamic = _isNonMonochrome(dynamicScheme);
    final scheme = useDynamic
        ? dynamicScheme!
        : ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF8A00),
            brightness: Brightness.light,
          );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'IBMPlexSans',
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

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: "Fast O'Clock",
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(lightDynamic),
          darkTheme: _buildDarkTheme(darkDynamic),
          themeMode: controller.settings.flutterThemeMode,
          home: home,
        );
      },
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
  String? _focusedRecordId;

  void _openTimeline([String? recordId]) {
    setState(() {
      _focusedRecordId = recordId;
      _selectedIndex = 1;
    });
  }

  List<Widget> get _pages => [
        FastingScreen(onOpenTimeline: _openTimeline),
        TimelineScreen(focusedRecordId: _focusedRecordId),
        const SettingsScreen(),
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
