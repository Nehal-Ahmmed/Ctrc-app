import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One entry in a [SubPageAppBar] overflow menu.
class SubPageMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool isDestructive;

  const SubPageMenuItem({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isDestructive = false,
  });
}

/// App bar for pages pushed on top of the shell.
///
/// The three-dot button used to be an empty callback. It now shows a real menu:
/// whatever the page passes in, followed by the entries every sub-page shares.
class SubPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Page-specific entries, listed above the shared ones.
  final List<SubPageMenuItem> menuItems;

  /// Extra actions placed to the left of the overflow button.
  final List<Widget> actions;

  /// Hides the overflow button entirely for pages that have nothing to offer.
  final bool showOverflowMenu;

  const SubPageAppBar({
    super.key,
    required this.title,
    this.menuItems = const [],
    this.actions = const [],
    this.showOverflowMenu = true,
  });

  void _pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = [
      ...menuItems,
      SubPageMenuItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        onSelected: () => context.push('/settings'),
      ),
      SubPageMenuItem(
        label: 'Help & FAQ',
        icon: Icons.help_outline,
        onSelected: () => context.push('/help'),
      ),
    ];

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _pop(context),
      ),
      title: Text(title),
      actions: [
        ...actions,
        if (showOverflowMenu)
          PopupMenuButton<SubPageMenuItem>(
            icon: const Icon(Icons.more_vert),
            onSelected: (item) => item.onSelected(),
            itemBuilder: (context) => entries
                .map(
                  (item) => PopupMenuItem<SubPageMenuItem>(
                    value: item,
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: item.isDestructive ? Colors.red : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item.label,
                          style: item.isDestructive
                              ? const TextStyle(color: Colors.red)
                              : null,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
