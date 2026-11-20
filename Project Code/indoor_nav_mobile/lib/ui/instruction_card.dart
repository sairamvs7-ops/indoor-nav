import 'package:flutter/material.dart';

import '../navigation/navigation_controller.dart';
import 'node_style.dart';

/// Where you are going, what to do next, and where you are now.
class InstructionCard extends StatelessWidget {
  const InstructionCard({super.key, required this.nav, required this.onPickDestination});

  final NavigationController nav;
  final VoidCallback onPickDestination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destination = nav.destinationNode;
    final current = nav.currentNode;
    final next = nav.nextNode;

    return Card(
      child: Padding(
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
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  nav.hasArrived ? Icons.flag : Icons.navigation_outlined,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(nav.instruction, key: const Key('instruction'), style: theme.textTheme.headlineSmall),
                ),
              ],
            ),
            if (current != null) ...[
              const SizedBox(height: 12),
              Text(
                'You are at ${current.name} · ${nav.map.floor(current.floor).name}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: nav.advanceToNextStop,
                  icon: const Icon(Icons.check),
                  label: Text(next.markerId == null ? "I'm at ${next.name} (no marker here)" : "I'm at ${next.name}"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
