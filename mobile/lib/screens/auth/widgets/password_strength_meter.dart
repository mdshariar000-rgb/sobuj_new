import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

@immutable
class PasswordStrength {
  const PasswordStrength({
    required this.hasMinLength,
    required this.hasSpecialChar,
    required this.hasDigit,
    required this.isBonusLength,
  });

  final bool hasMinLength;
  final bool hasSpecialChar;
  final bool hasDigit;

  /// A fourth, unlabeled bar segment for going past the 8-char minimum —
  /// only reachable once the other three are already met, so the bar never
  /// fills for a criterion the checklist doesn't tell the user about.
  final bool isBonusLength;

  factory PasswordStrength.evaluate(String password) {
    final hasMinLength = password.length >= 8;
    final hasSpecialChar = RegExp(
      r'[!@#$%^&*(),.?":{}|<>_\-]',
    ).hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);

    return PasswordStrength(
      hasMinLength: hasMinLength,
      hasSpecialChar: hasSpecialChar,
      hasDigit: hasDigit,
      isBonusLength:
          hasMinLength && hasSpecialChar && hasDigit && password.length >= 12,
    );
  }

  int get filledSegments => [
    hasMinLength,
    hasSpecialChar,
    hasDigit,
    isBonusLength,
  ].where((c) => c).length;

  String get label => switch (filledSegments) {
    0 => 'Too weak',
    1 => 'Weak',
    2 => 'Fair',
    3 => 'Good',
    _ => 'Strong',
  };
}

/// Live password-strength feedback shown under Register's password field —
/// every criterion here is real client-side validation, not decoration.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = PasswordStrength.evaluate(password);
    final percent = (strength.filledSegments / 4 * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  strength.filledSegments >= 3
                      ? Icons.verified_outlined
                      : Icons.info_outline,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${strength.label} Botanical Shield',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$percent% secured',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(4, (index) {
                final filled = index < strength.filledSegments;
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: filled
                          ? (index == 3 ? AppColors.mint : AppColors.primary)
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _CriterionLabel(met: strength.hasMinLength, text: '8+ chars'),
                _CriterionLabel(
                  met: strength.hasSpecialChar,
                  text: 'Special symbol',
                ),
                _CriterionLabel(met: strength.hasDigit, text: 'Number'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CriterionLabel extends StatelessWidget {
  const _CriterionLabel({required this.met, required this.text});

  final bool met;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: met ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: met ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
