import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/app_toast.dart';
import '../providers/auth_provider.dart';

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

  context.go('/home');

  AppToast.success(null, strings.signedOut);
}
