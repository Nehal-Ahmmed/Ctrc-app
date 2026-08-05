import 'package:flutter/material.dart';

import '../../../../core/widgets/sub_page_app_bar.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  static const _faqs = <({String question, String answer})>[
    (
      question: 'What does this app do?',
      answer:
          'CTRC collects traffic and road-condition reports from people on the '
          'road. Anything reported near you shows up in your feed, on the map, '
          'and along any route you plan.',
    ),
    (
      question: 'How do I report an incident?',
      answer:
          'Tap "What\'s happening nearby?" on the Home feed, or use the red '
          'alert button on the Map. On the Map you can also long-press anywhere '
          'to drop a pin and report at that exact spot instead of your own '
          'position.',
    ),
    (
      question: 'What does "link to an existing incident" mean?',
      answer:
          'If something is already reported close to where you are filing, the '
          'app asks whether it is the same event. Linking attaches your report '
          'as an update to that incident so everyone sees one thread instead of '
          'many duplicates. Choose "Report as new incident" if it is genuinely '
          'something else.',
    ),
    (
      question: 'Why is my feed empty?',
      answer:
          'The feed only shows incidents inside your report radius. Widen it in '
          'Settings › Report Radius, or pull down to refresh once your GPS has '
          'a fix.',
    ),
    (
      question: 'What do upvotes and downvotes do?',
      answer:
          'They are how the community confirms a report. Heavily upvoted '
          'reports are treated as more severe on the map; disputed ones are '
          'softened. Voting again removes your vote.',
    ),
    (
      question: 'How are notifications generated?',
      answer:
          'Whenever the app loads incidents near you, anything you have not '
          'seen before is added to your notifications. Turn this off in '
          'Settings › Nearby Incident Alerts.',
    ),
    (
      question: 'Do I need an account?',
      answer:
          'No — you can browse the feed, the map and route alerts as a guest. '
          'Reporting, voting, commenting and saving posts need an account.',
    ),
    (
      question: 'Why does the map ask for my location?',
      answer:
          'Your position decides which incidents are relevant and where a new '
          'report is filed. Location is used on the device and sent only with '
          'reports you choose to submit.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const SubPageAppBar(
        title: 'Help Center',
        showOverflowMenu: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Frequently asked questions',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._faqs.map(
            (faq) => ExpansionTile(
              leading: const Icon(Icons.help_outline),
              title: Text(
                faq.question,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faq.answer,
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Still stuck?',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.mail_outline),
            title: Text('Email support'),
            subtitle: Text('support@ctrc.app'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App version'),
            trailing: Text('v1.0.0'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
