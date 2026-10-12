import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/uk_address_fields.dart';

/// The user's full UK address. Two uses:
/// - [required]: shown by AuthGate to accounts made before the address was
///   required — they can't continue (only log out) until it's saved.
/// - otherwise: Profile → Privacy & Safety → Your address, to change it.
class AddressScreen extends ConsumerStatefulWidget {
  const AddressScreen({super.key, this.required = false});

  final bool required;

  @override
  ConsumerState<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends ConsumerState<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _form = UkAddressFormController(
    ref.read(authControllerProvider).valueOrNull?.address,
  );
  bool _isSaving = false;
  String? _postcodeError;
  String? _errorMessage;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _postcodeError = null;
      _errorMessage = null;
    });

    try {
      final resolved = await resolveUkAddress(ref, _form);
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            address: resolved.address,
            latitude: resolved.location.latitude,
            longitude: resolved.location.longitude,
            locationLabel: resolved.location.label,
          );
      if (!mounted) return;
      // Only claim success if the server really stored it — a server that
      // doesn't know about addresses yet ignores the fields.
      final saved = ref.read(authControllerProvider).valueOrNull?.address;
      if (saved?.postcode != resolved.address.postcode) {
        setState(
          () => _errorMessage =
              "Your address couldn't be saved right now. Please try again "
              'later.',
        );
        return;
      }
      // When required, AuthGate moves on by itself once needsAddress clears.
      if (!widget.required) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Address saved.')));
        Navigator.of(context).pop();
      }
    } on UnknownPostcodeException catch (e) {
      setState(() => _postcodeError = e.message);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = "Couldn't save your address. Try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.required ? 'Complete your address' : 'Your address'),
        automaticallyImplyLeading: !widget.required,
        actions: [
          if (widget.required)
            TextButton(
              key: const Key('address-logout'),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text('Log out'),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.required) ...[
                const Text(
                  'We now need your full UK address to keep Shobuj local '
                  'and safe. Only you and our team can see it — other '
                  'growers just see your town.',
                ),
                const SizedBox(height: 20),
              ],
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 12),
              ],
              UkAddressFields(
                form: _form,
                enabled: !_isSaving,
                postcodeError: _postcodeError,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('address-save'),
                onPressed: _isSaving ? null : _save,
                child: Text(widget.required ? 'Continue' : 'Save address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
