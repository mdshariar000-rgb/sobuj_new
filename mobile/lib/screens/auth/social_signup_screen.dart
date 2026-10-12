import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/uk_address.dart';
import '../../models/uk_location.dart';
import '../../providers/auth_providers.dart';
import '../../providers/onboarding_providers.dart';
import '../../services/api_exception.dart';
import '../../services/social_sign_in_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/uk_address_fields.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_screen.dart';
import 'widgets/auth_error_banner.dart';

/// After "Continue with Google / Apple" for someone new: what sign-up always
/// needs that the provider doesn't give us — the address (and a name, which
/// Apple sometimes withholds). Then the account is created and onboarding
/// starts, just like the email sign-up.
class SocialSignupScreen extends ConsumerStatefulWidget {
  const SocialSignupScreen({
    super.key,
    required this.credential,
    required this.email,
    this.suggestedName,
  });

  final SocialCredential credential;
  final String email;
  final String? suggestedName;

  @override
  ConsumerState<SocialSignupScreen> createState() => _SocialSignupScreenState();
}

class _SocialSignupScreenState extends ConsumerState<SocialSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.suggestedName,
  );
  final _address = UkAddressFormController();
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _postcodeError;
  Map<String, List<String>>? _fieldErrors;

  @override
  void dispose() {
    _nameController.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Please agree to the terms to continue.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _postcodeError = null;
      _fieldErrors = null;
    });

    final ({UkAddress address, UkLocation location}) resolved;
    try {
      resolved = await resolveUkAddress(ref, _address);
    } on UnknownPostcodeException catch (e) {
      setState(() {
        _postcodeError = e.message;
        _isSubmitting = false;
      });
      return;
    } catch (_) {
      setState(() {
        _errorMessage = "Couldn't check your postcode. Please try again.";
        _isSubmitting = false;
      });
      return;
    }

    ref.read(needsOnboardingProvider.notifier).state = true;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeSocialSignup(
            credential: widget.credential,
            name: _nameController.text.trim(),
            latitude: resolved.location.latitude,
            longitude: resolved.location.longitude,
            locationLabel: resolved.location.label,
            address: resolved.address,
          );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      setState(() {
        // The Google/Apple sign-in only lasts a few minutes.
        _errorMessage = e.statusCode == 401
            ? 'Your ${widget.credential.provider.label} sign-in timed out. '
                  'Go back and continue with ${widget.credential.provider.label} again.'
            : e.message;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted && ref.read(authControllerProvider).valueOrNull == null) {
        ref.read(needsOnboardingProvider.notifier).state = false;
      }
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _serverError(String field) => _fieldErrors?[field]?.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = widget.credential.provider.label;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Finish signing up')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Signed in with $provider as',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                widget.email,
                key: const Key('social-signup-email'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                AuthErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const Key('social-signup-name'),
                controller: _nameController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full name',
                  errorText: _serverError('name'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name.'
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                'Your address',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              UkAddressFields(
                form: _address,
                enabled: !_isSubmitting,
                postcodeError:
                    _postcodeError ??
                    _serverError('address_postcode') ??
                    _serverError('address_line1') ??
                    _serverError('address_city'),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      key: const Key('social-signup-terms'),
                      value: _agreedToTerms,
                      onChanged: (value) =>
                          setState(() => _agreedToTerms = value ?? false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textDark,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Use',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TermsScreen(),
                                ),
                              ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicyScreen(),
                                ),
                              ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('social-signup-submit'),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
