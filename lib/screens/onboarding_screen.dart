import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fast_protocol.dart';
import '../state/fasting_controller.dart';

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
                        final selected = _selectedProtocolId == preset.id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: selected
                              ? theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.4)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: selected
                                ? BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 1.5,
                                  )
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                _selectedProtocolId = preset.id;
                              });
                            },
                            title: Text(
                              preset.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(preset.description),
                            trailing: selected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                          ),
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
