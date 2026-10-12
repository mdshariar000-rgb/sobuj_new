import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/uk_address.dart';
import '../../models/uk_location.dart';
import '../../widgets/uk_address_fields.dart';
import '../../providers/auth_providers.dart';
import '../../providers/onboarding_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_screen.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/farming_interest_grid.dart';
import 'widgets/interest_chips.dart';
import 'widgets/password_strength_meter.dart';
import 'widgets/social_sign_in_buttons.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _locationFieldKey = GlobalKey();

  ExperienceLevel? _experienceLevel;
  GrowingSetup? _growingSetup;
  final Set<String> _interests = {};
  final _address = UkAddressFormController();
  String? _postcodeError;
  bool _agreedToTerms = false;

  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, List<String>>? _fieldErrors;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      _fieldErrors = null;
      _postcodeError = null;
    });

    // The postcode gives the account its map location and town.
    final ({UkAddress address, UkLocation location}) resolved;
    try {
      resolved = await resolveUkAddress(ref, _address);
    } on UnknownPostcodeException catch (e) {
      setState(() {
        _postcodeError = e.message;
        _isSubmitting = false;
      });
      _scrollToLocationField();
      return;
    } catch (_) {
      setState(() {
        _errorMessage = "Couldn't check your postcode. Please try again.";
        _isSubmitting = false;
      });
      return;
    }
    final location = resolved.location;

    // Set before registering, so the moment the account exists AuthGate
    // goes straight to onboarding rather than flashing Home first.
    ref.read(needsOnboardingProvider.notifier).state = true;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _confirmPasswordController.text,
            latitude: location.latitude,
            longitude: location.longitude,
            locationLabel: location.label,
            experienceLevel: _experienceLevel?.value,
            growingSetup: _growingSetup?.value,
            growingInterests: _interests.toList(),
            address: resolved.address,
          );
      // AuthGate swaps its child to the signed-in shell once register() sets
      // the signed-in state, but this screen was reached via Navigator.push
      // from LoginScreen — unlike Login (AuthGate's direct child), that push
      // leaves RegisterScreen sitting on top of the nav stack regardless of
      // what AuthGate is now building underneath, so it has to be explicitly
      // popped for the user to actually see the swap.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      // Whatever went wrong, no account means no onboarding to show.
      if (mounted && ref.read(authControllerProvider).valueOrNull == null) {
        ref.read(needsOnboardingProvider.notifier).state = false;
      }
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _serverError(String field) => _fieldErrors?[field]?.first;

  void _scrollToLocationField() {
    final context = _locationFieldKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.forestDark, AppColors.forestPanel],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _HeaderIconButton(
                          icon: Icons.arrow_back,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '🌱 SHOBUJ COMMUNITY',
                            style: TextStyle(
                              color: AppColors.mint,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        _HeaderIconButton(
                          icon: Icons.my_location,
                          onPressed: _scrollToLocationField,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Create Your Account',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connecting communities through sustainable gardening '
                      'and nature.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          AuthErrorBanner(message: _errorMessage!),
                          const SizedBox(height: 16),
                        ],
                        const _FieldLabel('Your Address'),
                        const SizedBox(height: 6),
                        UkAddressFields(
                          key: _locationFieldKey,
                          form: _address,
                          enabled: !_isSubmitting,
                          postcodeError:
                              _postcodeError ??
                              _serverError('address_postcode') ??
                              _serverError('address_line1') ??
                              _serverError('address_city'),
                        ),
                        const SizedBox(height: 20),
                        const _FieldLabel('Full Name'),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('register-name-field'),
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: InputDecoration(
                            hintText: 'e.g. Maya Lin',
                            prefixIcon: const Icon(Icons.person_outline),
                            errorText: _serverError('name'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Email Address'),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('register-email-field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            hintText: 'maya.agri@example.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            errorText: _serverError('email'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your email.';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const _FieldLabel('What are your interests?'),
                            const Spacer(),
                            Text(
                              'optional',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        InterestChips(
                          selected: _interests,
                          onToggle: (interest) => setState(
                            () => _interests.contains(interest)
                                ? _interests.remove(interest)
                                : _interests.add(interest),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const _FieldLabel('Where do you grow?'),
                            const Spacer(),
                            Text(
                              'optional',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FarmingInterestGrid(
                          value: _growingSetup,
                          onChanged: (setup) =>
                              setState(() => _growingSetup = setup),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ExperienceLevel>(
                          initialValue: _experienceLevel,
                          decoration: const InputDecoration(
                            labelText: 'Experience level (optional)',
                          ),
                          // Expert stays in the enum so existing accounts
                          // still load, but new sign-ups can't pick it.
                          items: ExperienceLevel.values
                              .where((level) => level != ExperienceLevel.expert)
                              .map(
                                (level) => DropdownMenuItem(
                                  value: level,
                                  child: Text(level.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _experienceLevel = value),
                        ),
                        const SizedBox(height: 20),
                        const _FieldLabel('Password'),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('register-password-field'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            hintText: 'Create a strong password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            errorText: _serverError('password'),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter a password.';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        PasswordStrengthMeter(
                          password: _passwordController.text,
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Confirm Password'),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('register-confirm-password-field'),
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Re-enter your password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                key: const Key('register-terms-checkbox'),
                                value: _agreedToTerms,
                                onChanged: (value) => setState(
                                  () => _agreedToTerms = value ?? false,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: RichText(
                                  text: TextSpan(
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.textDark),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Agricultural Data Sharing',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        recognizer: (TapGestureRecognizer()
                                          ..onTap = () =>
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const TermsScreen(),
                                                ),
                                              )),
                                      ),
                                      const TextSpan(text: ' terms and '),
                                      TextSpan(
                                        text: 'Shobuj Privacy Policy',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        recognizer: (TapGestureRecognizer()
                                          ..onTap = () =>
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const PrivacyPolicyScreen(),
                                                ),
                                              )),
                                      ),
                                      const TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          key: const Key('register-submit-button'),
                          onPressed: _isSubmitting ? null : _submit,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const SizedBox.shrink(),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Create Free Account'),
                              if (!_isSubmitting) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SocialSignInButtons(
                          dividerLabel: 'OR REGISTER WITH',
                          enabled: !_isSubmitting,
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                              children: const [
                                TextSpan(text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Log In',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Your data is encrypted and secure',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
