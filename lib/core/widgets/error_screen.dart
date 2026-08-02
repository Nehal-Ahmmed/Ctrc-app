import 'package:flutter/material.dart';

/// The calm thing that sits where a widget failed to build.
///
/// Flutter's default is a red box full of framework text (grey in release),
/// which is the single ugliest thing a user can be shown. This keeps the same
/// job — occupy the broken widget's slot — while looking like part of the app.
/// In debug builds the real exception text is kept underneath so the failure is
/// still diagnosable at a glance.
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, required this.message, this.detail});

  final String message;

  /// Raw exception text. Only pass this in debug builds.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    // ErrorWidget.builder can run before (or after) there is a Theme or
    // Directionality in scope, so nothing here may assume an inherited widget.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        color: const Color(0xFFF5F3F7),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: Color(0xFFB3261E),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1D1B20),
                  decoration: TextDecoration.none,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: Color(0xFF6B6570),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
