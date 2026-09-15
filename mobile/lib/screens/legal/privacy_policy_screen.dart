import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agro Hub Privacy Policy')),
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
              'and anything you post — group posts, comments, events, and '
              'messages to the Agri-AI Assistant, including photos you choose '
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
              "A photo or message you send to the Agri-AI Assistant is sent to "
              "Google's Gemini API to generate a response. No other "
              'content is shared with third parties.',
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
