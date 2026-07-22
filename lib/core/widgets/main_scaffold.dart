import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/Auth/presentation/providers/auth_provider.dart';

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
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
                  const DrawerHeader(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                    ),
                    child: Text(
                      'Menu',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  if (isAuth) ...[
                    ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: const Text('My Reports'),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('My Reports coming soon')));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.bookmark_border),
                      title: const Text('Saved Posts'),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved Posts coming soon')));
                      },
                    ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.directions),
                    title: const Text('Map Route'),
                    onTap: () {
                      Navigator.pop(context);
                      _onTap(1); // Go to Map
                      // Additional logic to trigger routing mode can be handled via state
                    },
                  ),
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
