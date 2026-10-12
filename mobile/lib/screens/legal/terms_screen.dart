import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agricultural Data Sharing Terms')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What you share on Shobuj',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Groups, posts, comments, and events you create are visible to '
              'other members of the group or the general community feed, '
              'depending on where you post them. Your name is shown alongside '
              'anything you post.',
            ),
            SizedBox(height: 20),
            Text(
              'Location',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Your device location is used to power nearby discovery '
              'features. A randomized, fuzzed approximation of your location '
              'is what other users ever see — never your exact coordinates.',
            ),
            SizedBox(height: 20),
            Text(
              'Photos',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Photos you attach to a post, listing, event or message are '
              'stored to display it.',
            ),
            SizedBox(height: 20),
            Text(
              'Acceptable content',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Shobuj has zero tolerance for objectionable content or '
              'abusive users. Do not post anything hateful, harassing, '
              'sexually explicit, violent, misleading, spam, or illegal — '
              'including banned or invasive plant species.',
            ),
            SizedBox(height: 20),
            Text(
              'Reporting and blocking',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'You can report any post, comment, listing, event, group, '
              'message, or user, and block any user, from the ⋮ menu or by '
              'long-pressing a message. We review reports promptly — aiming '
              'for within 24 hours — and remove content or suspend accounts '
              'that break these terms.',
            ),
            SizedBox(height: 24),
            Text(
              'This is a plain-language summary of current app behavior, not '
              'a legally reviewed document.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
