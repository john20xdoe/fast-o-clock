import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fast_protocol.dart';
import '../state/fasting_controller.dart';
import '../widgets/protocol_picker.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedProtocolId = '16_8';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.read<FastingController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.timelapse_rounded,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Fast O'Clock",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'time to fast — a simple, private fasting tracker for beginners and pros alike.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pick your default fasting rhythm:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 5,
                    child: ListView(
                      children: FastProtocol.presets.map((preset) {
                        return ProtocolPresetCard(
                          preset: preset,
                          isSelected: _selectedProtocolId == preset.id,
                          bottomMargin: 10,
                          borderRadius: 14,
                          onTap: () {
                            setState(() {
                              _selectedProtocolId = preset.id;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        controller.completeOnboarding(
                          defaultProtocolId: _selectedProtocolId,
                        );
                      },
                      child: const Text('Continue'),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
