import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../../../services/api_exception.dart';
import '../../../theme/app_colors.dart';

/// "Want to make a new group? Request a group" — the footer under the Groups
/// list. Only admins create groups; this sends them a request.
class RequestGroupFooter extends StatelessWidget {
  const RequestGroupFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        children: [
          Text(
            'Want to make a new group?',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          TextButton(
            key: const Key('request-group-button'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _RequestGroupSheet(),
            ),
            child: const Text('Request a group'),
          ),
        ],
      ),
    );
  }
}

class _RequestGroupSheet extends ConsumerStatefulWidget {
  const _RequestGroupSheet();

  @override
  ConsumerState<_RequestGroupSheet> createState() => _RequestGroupSheetState();
}

class _RequestGroupSheetState extends ConsumerState<_RequestGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final description = _descriptionController.text.trim();
      await ref
          .read(apiClientProvider)
          .requestGroup(
            name: _nameController.text.trim(),
            description: description.isEmpty ? null : description,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks — our team will review your group request.'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Request a group',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tell us what the group is for. Our team reviews every request.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              key: const Key('request-group-name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group name'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a name for the group.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('request-group-description'),
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What is it for? (optional)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('request-group-submit'),
              onPressed: _isSubmitting ? null : _submit,
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
  }
}
