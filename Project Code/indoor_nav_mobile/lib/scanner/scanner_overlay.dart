import 'package:flutter/material.dart';

/// Aiming square and status text drawn over the camera preview.
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key, required this.hint, required this.confirmed});

  final String hint;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final color = confirmed ? Colors.greenAccent : Colors.white;
    return Column(
      children: [
        const Spacer(flex: 3),
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: confirmed ? Icon(Icons.check_circle, color: color, size: 72) : null,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(flex: 4),
      ],
    );
  }
}

/// Close and flashlight buttons. Always visible, even when the camera fails.
class ScannerTopBar extends StatelessWidget {
  const ScannerTopBar({super.key, required this.torchOn, required this.onClose, this.onToggleTorch});

  final bool torchOn;
  final VoidCallback onClose;
  final VoidCallback? onToggleTorch;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close scanner',
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
              const Spacer(),
              if (onToggleTorch != null)
                IconButton(
                  tooltip: torchOn ? 'Turn flashlight off' : 'Turn flashlight on',
                  onPressed: onToggleTorch,
                  icon: Icon(torchOn ? Icons.flashlight_off : Icons.flashlight_on, color: Colors.white, size: 28),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraErrorView extends StatelessWidget {
  const CameraErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
