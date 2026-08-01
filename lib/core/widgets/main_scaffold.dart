import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/Auth/presentation/providers/auth_provider.dart';
import '../../features/Map/domain/models/map_scope.dart';
import '../../features/Map/presentation/providers/map_controls_provider.dart';

/// Index of the Map branch inside the [StatefulShellRoute].
const int _mapBranchIndex = 1;

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Drawer entries for the map services: switch to the map first, then hand
  /// the action over to the map page through [mapCommandProvider].
  void _runMapAction(BuildContext context, WidgetRef ref, MapAction action) {
    Navigator.pop(context);
    _onTap(_mapBranchIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapCommandProvider.notifier).dispatch(action);
    });
  }

  /// The map's own services, mirrored into the drawer so every standard map
  /// capability is reachable from the side bar as well as from the map itself.
  List<Widget> _buildMapSection(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(mapScopeProvider);
    final areaAlerts = ref.watch(mapAreaAlertCountProvider);
    final routeAlerts = ref.watch(mapRouteAlertCountProvider);

    Widget tile(MapAction action, {String? badge}) {
      return ListTile(
        leading: Icon(action.icon),
        title: Text(action.title),
        subtitle: Text(
          action.subtitle,
          style: const TextStyle(fontSize: 11.5),
        ),
        trailing: badge == null
            ? null
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
        onTap: () => _runMapAction(context, ref, action),
      );
    }

    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          'MAP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: Colors.grey,
          ),
        ),
      ),
      tile(MapAction.recenter),
      tile(MapAction.openSearch),
      tile(MapAction.reportIncident),
      tile(MapAction.openRoutePlanner),
      tile(MapAction.openAreaAlerts, badge: '$areaAlerts'),
      tile(
        MapAction.openRouteAlerts,
        badge: routeAlerts == null ? null : '$routeAlerts',
      ),
      if (routeAlerts != null) tile(MapAction.clearRoute),
      ExpansionTile(
        leading: Icon(scope.icon),
        title: const Text('Alert radius'),
        subtitle: Text(
          scope.label,
          style: const TextStyle(fontSize: 11.5),
        ),
        childrenPadding: const EdgeInsets.only(left: 16),
        children: [
          RadioGroup<MapScope>(
            groupValue: scope,
            onChanged: (selected) {
              if (selected == null) return;
              ref.read(mapScopeProvider.notifier).state = selected;
              Navigator.pop(context);
              _onTap(_mapBranchIndex);
            },
            child: Column(
              children: MapScope.values
                  .map(
                    (option) => RadioListTile<MapScope>(
                      value: option,
                      dense: true,
                      title: Text(option.label),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAuth = authState.status == AuthStatus.authenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CTRC System'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          if (!isAuth)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: ElevatedButton(
                onPressed: () => context.push('/sign-in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Log In'),
              ),
            ),
          if (isAuth)
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {},
            ),
          if (isAuth && authState.user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GestureDetector(
                onTap: () {
                  _onTap(2); // Index 2 is Profile in BottomNavigationBar
                },
                child: CircleAvatar(
                  backgroundImage: (authState.user!.image_url != null && authState.user!.image_url!.isNotEmpty)
                      ? NetworkImage(authState.user!.image_url!)
                      : null,
                  child: (authState.user!.image_url == null || authState.user!.image_url!.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Crowdsourced Traffic\n& Road Condition',
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isAuth && authState.user != null) ...[
                          const Spacer(),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                backgroundImage: (authState.user!.image_url != null && authState.user!.image_url!.isNotEmpty)
                                    ? NetworkImage(authState.user!.image_url!)
                                    : null,
                                child: (authState.user!.image_url == null || authState.user!.image_url!.isEmpty)
                                    ? const Icon(Icons.person, size: 30, color: Colors.blue)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      authState.user!.name.isNotEmpty ? authState.user!.name : 'User',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (authState.user!.address != null && authState.user!.address!.isNotEmpty)
                                      Text(
                                        authState.user!.address!,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    else
                                      const Text(
                                        'Unknown Location',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isAuth) ...[
                    ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: const Text('My Reports'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/my-reports');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.bookmark_border),
                      title: const Text('Saved Posts'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/saved-posts');
                      },
                    ),
                  ],
                  ..._buildMapSection(context, ref),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context); // close drawer
                      context.push('/settings'); // go to settings (sub-page)
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: isAuth
                    ? ListTile(
                        leading: const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                        onTap: () {
                          Navigator.pop(context); // close drawer
                          ref.read(authProvider.notifier).signOut();
                          context.go('/home'); // ensure they are back to home
                        },
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // close drawer
                              context.push('/sign-in');
                            },
                            icon: const Icon(Icons.login, color: Colors.white),
                            label: const Text('Log In', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // close drawer
                              context.push('/sign-up');
                            },
                            icon: const Icon(Icons.person_add, color: Colors.white),
                            label: const Text('Sign Up', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
