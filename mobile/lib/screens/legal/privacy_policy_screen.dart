import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shobuj Privacy Policy')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What we collect',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Your name, email, and password; an approximate device location; '
              'and anything you post — group posts, comments, events, '
              'marketplace listings and messages, including photos you choose '
              'to share.',
            ),
            SizedBox(height: 20),
            Text(
              'How it is stored',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Your password is one-way hashed — it is never stored or '
              'transmitted in plain text. Your sign-in session is kept in '
              "this device's secure keystore/keychain, not in ordinary app "
              'storage. All traffic between the app and our servers is '
              'encrypted (HTTPS).',
            ),
            SizedBox(height: 20),
            Text(
              'Third parties',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Push notifications are delivered through Google\'s Firebase '
              'Cloud Messaging. No other content is shared with third '
              'parties, and we do not sell your data or use it for '
              'advertising.',
            ),
            SizedBox(height: 20),
            Text(
              'Deleting your data',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'You can permanently delete your account and all of your data '
              'at any time from Profile → Privacy & Safety → Delete account. '
              'The full policy is also available online at '
              'codecell.site/privacy.',
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
