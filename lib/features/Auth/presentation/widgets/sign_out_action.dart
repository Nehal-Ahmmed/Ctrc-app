import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/app_toast.dart';
import '../providers/auth_provider.dart';

/// Confirms, then signs out and returns the app to the guest home feed.
///
/// Every sign-out entry point — the drawer, Settings and the profile page —
/// routes through here, so one tap always produces the same result: the same
/// confirmation, the session actually cleared before navigating, and a `go`
/// rather than a `push` so no account-only page survives underneath.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final strings = ref.read(appStringsProvider);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(strings.logOutQuestion),
      content: Text(strings.logOutWarning),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            strings.logOut,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await ref.read(authProvider.notifier).signOut();
  if (!context.mounted) return;

  // `go`, not `pop`: the whole stack is thrown away so anything account-only
  // sitting behind the current page goes with it.
  context.go('/home');

  // No context: the page that asked for the sign-out is usually one of the ones
  // just torn down, so the toast goes to the root overlay instead.
  AppToast.success(null, strings.signedOut);
}
