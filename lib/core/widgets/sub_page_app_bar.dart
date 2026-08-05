import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

class SubPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  final List<SubPageMenuItem> menuItems;

  final List<Widget> actions;

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
