import 'package:flutter/material.dart';
import '../../../../core/widgets/sub_page_app_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: SubPageAppBar(title: 'Settings'),
      body: Center(
        child: Text('Settings (Bottom Nav Hidden)'),
      ),
    );
  }
}
