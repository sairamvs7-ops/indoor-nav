import 'package:flutter/material.dart';

import '../navigation/navigation_controller.dart';
import 'node_style.dart';

/// Where you are going, what to do next, and where you are now.
class InstructionCard extends StatelessWidget {
  const InstructionCard({
    super.key,
    required this.nav,
    required this.onPickDestination,
    this.livePrompt,
    this.liveRemaining,
  });

  final NavigationController nav;
  final VoidCallback onPickDestination;

  /// While walking: the next turn ("In 12 m, turn left") instead of the
  /// next stop, and how far is left.
  final String? livePrompt;
  final double? liveRemaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final destination = nav.destinationNode;
    final current = nav.currentNode;
    final next = nav.nextNode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.primaryContainer,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(8),
                  child: Icon(nav.hasArrived ? Icons.flag : Icons.navigation, color: scheme.onPrimary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    (livePrompt?.isNotEmpty ?? false) ? livePrompt! : nav.instruction,
                    key: const Key('instruction'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickDestination,
                  icon: Icon(destination == null ? Icons.search : iconFor(destination.type)),
                  label: Text(destination == null ? 'Choose a destination' : 'Going to ${destination.name}'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                if (liveRemaining != null) ...[
                  Text(
                    '${liveRemaining!.round()} m to go',
                    style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(height: 8),
                ],
                if (current != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.my_location, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are at ${current.name} · ${nav.map.floor(current.floor).name}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
                if (next != null) ...[
                  const SizedBox(height: 12),
                  // Move on without scanning, so the camera can stay off.
                  FilledButton.tonalIcon(
                    onPressed: nav.advanceToNextStop,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: Text(next.markerId == null ? 'Next: ${next.name} (no marker)' : 'Next: ${next.name}'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
