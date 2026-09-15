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
              'What you share on Agro Hub',
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
              'Photos and the Agri-AI Assistant',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'A leaf photo you send to the Agri-AI Assistant is sent to '
              "Google's Gemini API for analysis so the assistant can "
              'respond. Photos you attach to a post are stored to display '
              'that post.',
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
