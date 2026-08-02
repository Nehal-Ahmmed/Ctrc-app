import 'package:flutter/material.dart';

import '../../../../core/widgets/sub_page_app_bar.dart';

/// Settings › Privacy Policy, previously an empty `onTap`.
///
/// The text below describes what this app actually does today — location used
/// for nearby lookups, reports stored with their coordinates, avatars on
/// Cloudinary — rather than boilerplate.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _sections = <({String title, String body})>[
    (
      title: 'What we collect',
      body:
          'Account details you give us: your name, email address, and '
          'optionally an address and profile picture.\n\n'
          'Content you create: incident reports, comments, votes and saved '
          'posts, each stored with the coordinates you filed them at.\n\n'
          'Device location: read while the app is open so we can show what is '
          'happening around you.',
    ),
    (
      title: 'How your location is used',
      body:
          'Your position is used on the device to centre the map, to fetch '
          'incidents inside your report radius, and to measure how far away '
          'each incident is.\n\n'
          'It is sent to our servers only as part of a report you choose to '
          'submit, or as the search centre of a nearby lookup. We do not keep '
          'a history of where you have been.',
    ),
    (
      title: 'What other people can see',
      body:
          'Reports and comments are public inside the app: your display name '
          'and profile picture appear next to them, along with the location of '
          'the incident. Anyone who voted on a report can be seen by tapping '
          'its vote count.\n\n'
          'Your email address and home address are never shown to other users.',
    ),
    (
      title: 'Third-party services',
      body:
          'Map tiles and place search come from OpenStreetMap and Nominatim. '
          'Route lines come from a public routing service. These receive the '
          'coordinates needed to answer the request.\n\n'
          'Profile pictures are stored with Cloudinary.',
    ),
    (
      title: 'Data stored on your device',
      body:
          'Your login token, your app preferences (theme, language, report '
          'radius, alert setting) and your notification history are stored '
          'locally. Signing out clears the login token.',
    ),
    (
      title: 'Your choices',
      body:
          'You can browse the app as a guest without an account.\n\n'
          'You can turn off nearby incident alerts in Settings.\n\n'
          'You can deny or revoke the location permission at any time from your '
          'device settings; the map will still work, centred on a default '
          'position, but nearby lookups and reporting will not.',
    ),
    (
      title: 'Contact',
      body:
          'Questions about this policy, or a request to remove your data, can '
          'be sent to support@ctrc.app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const SubPageAppBar(
        title: 'Privacy Policy',
        showOverflowMenu: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(
            'How CTRC handles your data',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Last updated: 1 August 2026',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ..._sections.expand(
            (section) => [
              Text(
                section.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                section.body,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 22),
            ],
          ),
        ],
      ),
    );
  }
}
