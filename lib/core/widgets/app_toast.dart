import 'dart:async';

import 'package:flutter/material.dart';

import '../errors/app_error.dart';
import '../router/root_navigator_key.dart';

enum ToastVariant { success, error, warning, info }

class ToastAction {
  const ToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

abstract final class AppToast {
  
  static const _maxVisible = 3;

  static const _defaultDuration = Duration(seconds: 3);
  static const _errorDuration = Duration(seconds: 4);

  static final ValueNotifier<List<_ToastData>> _toasts = ValueNotifier(const []);
  static OverlayEntry? _entry;
  static OverlayState? _overlay;
  static int _nextId = 0;

  static void error(
    BuildContext? context,
    Object? error, {
    String? title,
    Duration? duration,
    ToastAction? action,
  }) {
    final described = AppError.from(error);
    debugPrint('AppToast.error: ${described.raw ?? described}');
    _push(
      context,
      _ToastData(
        id: _nextId++,
        title: title ?? described.title,
        message: described.message,
        variant: ToastVariant.error,
        duration: duration ?? _errorDuration,
        action: action,
      ),
    );
  }

  static void success(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) =>
      show(
        context,
        message,
        variant: ToastVariant.success,
        title: title,
        duration: duration,
      );

  static void warning(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) =>
      show(
        context,
        message,
        variant: ToastVariant.warning,
        title: title,
        duration: duration,
      );

  static void info(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) =>
      show(
        context,
        message,
        variant: ToastVariant.info,
        title: title,
        duration: duration,
      );

  static void show(
    BuildContext? context,
    String message, {
    ToastVariant variant = ToastVariant.info,
    String? title,
    Duration? duration,
    ToastAction? action,
  }) {
    _push(
      context,
      _ToastData(
        id: _nextId++,
        title: title,
        message: message,
        variant: variant,
        duration: duration ??
            (variant == ToastVariant.error ? _errorDuration : _defaultDuration),
        action: action,
      ),
    );
  }

  static void dismissAll() => _toasts.value = const [];

  static void _push(BuildContext? context, _ToastData data) {
    final overlay = _resolveOverlay(context);
    if (overlay == null) {
      
      debugPrint('AppToast: no overlay available — "${data.message}"');
      return;
    }

    if (!identical(overlay, _overlay)) {
      _detach();
      _overlay = overlay;
    }
    _attach();

    final current = _toasts.value;
    
    if (current.any((t) => t.message == data.message && t.title == data.title)) {
      return;
    }

    final next = [...current, data];
    _toasts.value = next.length > _maxVisible
        ? next.sublist(next.length - _maxVisible)
        : next;
  }

  static OverlayState? _resolveOverlay(BuildContext? context) {
    if (context != null && context.mounted) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) return overlay;
    }
    final rootContext = rootNavigatorKey.currentContext;
    if (rootContext == null) return null;
    return Overlay.maybeOf(rootContext, rootOverlay: true);
  }

  static void _attach() {
    if (_entry != null) return;
    final entry = OverlayEntry(builder: (context) => const _ToastLayer());
    _entry = entry;
    _overlay!.insert(entry);
  }

  static void _detach() {
    _entry?.remove();
    _entry = null;
    _overlay = null;
    _toasts.value = const [];
  }

  static void _remove(int id) {
    _toasts.value = _toasts.value.where((t) => t.id != id).toList();
    
  }
}

class _ToastData {
  const _ToastData({
    required this.id,
    required this.title,
    required this.message,
    required this.variant,
    required this.duration,
    this.action,
  });

  final int id;
  final String? title;
  final String message;
  final ToastVariant variant;
  final Duration duration;
  final ToastAction? action;
}

class _ToastLayer extends StatelessWidget {
  const _ToastLayer();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ValueListenableBuilder<List<_ToastData>>(
            valueListenable: AppToast._toasts,
            builder: (context, toasts, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final toast in toasts)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _ToastCard(
                        key: ValueKey(toast.id),
                        data: toast,
                        onDismissed: () => AppToast._remove(toast.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({super.key, required this.data, required this.onDismissed});

  final _ToastData data;
  final VoidCallback onDismissed;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with TickerProviderStateMixin {
  static const _enterDuration = Duration(milliseconds: 260);

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _enterDuration,
    reverseDuration: const Duration(milliseconds: 180),
  );

  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: widget.data.duration,
  );

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _life.forward().then((_) {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _life.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_leaving) return;
    _leaving = true;
    _life.stop();
    await _entrance.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme, widget.data.variant);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.6),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entrance,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      )),
      child: FadeTransition(
        opacity: _entrance,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: _dismiss,
            
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -80) _dismiss();
            },
            child: Material(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHigh
                  : theme.colorScheme.surface,
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.22),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: palette.accent.withValues(alpha: isDark ? 0.35 : 0.22),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          
                          Container(width: 4, color: palette.accent),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 12, 8, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: palette.accent
                                          .withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      palette.icon,
                                      size: 18,
                                      color: palette.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (widget.data.title != null) ...[
                                          Text(
                                            widget.data.title!,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          widget.data.message,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            height: 1.35,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        if (widget.data.action != null)
                                          _ActionButton(
                                            action: widget.data.action!,
                                            accent: palette.accent,
                                            onTapped: _dismiss,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  _CloseButton(onPressed: _dismiss),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    AnimatedBuilder(
                      animation: _life,
                      builder: (context, _) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          widthFactor: 1 - _life.value,
                          child: Container(
                            height: 2,
                            color: palette.accent.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.accent,
    required this.onTapped,
  });

  final ToastAction action;
  final Color accent;

  final VoidCallback onTapped;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () {
          action.onPressed();
          onTapped();
        },
        style: TextButton.styleFrom(
          foregroundColor: accent,
          
          padding: const EdgeInsetsDirectional.only(end: 8),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(action.label),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.close_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                alpha: 0.7,
              ),
        ),
      ),
    );
  }
}

({Color accent, IconData icon}) _palette(ThemeData theme, ToastVariant variant) {
  final isDark = theme.brightness == Brightness.dark;
  return switch (variant) {
    ToastVariant.success => (
        accent: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
        icon: Icons.check_circle_outline_rounded,
      ),
    ToastVariant.error => (
        accent: theme.colorScheme.error,
        icon: Icons.error_outline_rounded,
      ),
    ToastVariant.warning => (
        accent: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        icon: Icons.warning_amber_rounded,
      ),
    ToastVariant.info => (
        accent: theme.colorScheme.primary,
        icon: Icons.info_outline_rounded,
      ),
  };
}
