import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/uk_address.dart';
import '../models/uk_location.dart';
import '../providers/core_providers.dart';
import '../services/api_exception.dart';

/// Text controllers for [UkAddressFields] — owned by the screen.
class UkAddressFormController {
  UkAddressFormController([UkAddress? initial])
    : line1 = TextEditingController(text: initial?.line1),
      line2 = TextEditingController(text: initial?.line2),
      city = TextEditingController(text: initial?.city),
      county = TextEditingController(text: initial?.county),
      postcode = TextEditingController(text: initial?.postcode);

  final TextEditingController line1;
  final TextEditingController line2;
  final TextEditingController city;
  final TextEditingController county;
  final TextEditingController postcode;

  void dispose() {
    for (final controller in [line1, line2, city, county, postcode]) {
      controller.dispose();
    }
  }
}

/// "ls63aa" / "LS6  3AA" → "LS6 3AA" — same as the backend's UkAddress.
String normaliseUkPostcode(String postcode) {
  final compact = postcode.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return compact.length > 3
      ? '${compact.substring(0, compact.length - 3)} '
            '${compact.substring(compact.length - 3)}'
      : compact;
}

final _postcodeFormat = RegExp(
  r'^[A-Z]{1,2}\d[A-Z\d]? \d[A-Z]{2}$',
  caseSensitive: false,
);

/// Thrown by [resolveUkAddress] when the postcode isn't a real one.
class UnknownPostcodeException implements Exception {
  const UnknownPostcodeException();

  String get message => "We couldn't find that postcode. Please check it.";
}

/// The typed address plus where its postcode is — the account's map
/// location. Throws [UnknownPostcodeException] for an unknown postcode.
Future<({UkAddress address, UkLocation location})> resolveUkAddress(
  WidgetRef ref,
  UkAddressFormController form,
) async {
  final postcode = normaliseUkPostcode(form.postcode.text);
  final location = await ref
      .read(ukLocationServiceProvider)
      .lookupPostcode(postcode);
  if (location == null) throw const UnknownPostcodeException();

  String? optional(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  return (
    address: UkAddress(
      line1: form.line1.text.trim(),
      line2: optional(form.line2),
      city: form.city.text.trim(),
      county: optional(form.county),
      postcode: postcode,
    ),
    location: location,
  );
}

/// UK address, postcode first: type the postcode, tap "Find address" and
/// pick yours from Royal Mail's list — the rest fills itself in. "My
/// address isn't listed" (or lookups not being set up on the server) opens
/// the lines to type by hand, with the town already filled from the
/// postcode.
class UkAddressFields extends ConsumerStatefulWidget {
  const UkAddressFields({
    super.key,
    required this.form,
    this.postcodeError,
    this.enabled = true,
  });

  final UkAddressFormController form;

  /// e.g. "We couldn't find that postcode" from the screen's submit.
  final String? postcodeError;
  final bool enabled;

  @override
  ConsumerState<UkAddressFields> createState() => _UkAddressFieldsState();
}

class _UkAddressFieldsState extends ConsumerState<UkAddressFields> {
  bool _isLookingUp = false;
  String? _lookupError;

  /// The addresses at the postcode, waiting for the user to pick one.
  List<AddressSuggestion> _addresses = const [];

  /// Typing the lines by hand instead of picking from the list.
  bool _manual = false;

  /// Set when the manual lines opened because the list isn't available.
  String? _manualNote;

  UkAddressFormController get _form => widget.form;

  bool get _hasAddress => _form.line1.text.trim().isNotEmpty;

  void _clearLines() {
    for (final c in [_form.line1, _form.line2, _form.city, _form.county]) {
      c.clear();
    }
  }

  /// Editing the postcode after picking an address starts over.
  void _onPostcodeChanged(String _) {
    if (_manual || (!_hasAddress && _addresses.isEmpty)) return;
    setState(() {
      _clearLines();
      _addresses = const [];
    });
  }

  Future<void> _find() async {
    final postcode = normaliseUkPostcode(_form.postcode.text);
    if (!_postcodeFormat.hasMatch(postcode)) {
      setState(() => _lookupError = 'Enter a full UK postcode, e.g. LS6 3AA.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLookingUp = true;
      _lookupError = null;
      _addresses = const [];
      _manual = false;
      _manualNote = null;
    });
    _form.postcode.text = postcode;
    _clearLines();

    try {
      final addresses = await ref
          .read(apiClientProvider)
          .postcodeAddresses(postcode);
      if (!mounted) return;
      if (addresses.isEmpty) {
        await _openManual(
          postcode,
          note: 'Enter your house number and street.',
        );
      } else {
        setState(() => _addresses = addresses);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        setState(() => _lookupError = const UnknownPostcodeException().message);
      } else {
        // Lookups not set up, out of credits, or down: type it in instead.
        await _openManual(
          postcode,
          note: 'Enter your house number and street.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _lookupError = "Couldn't look that up. Try again.");
      }
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  /// Opens the lines to type by hand, with the town and county filled in
  /// from the postcode where it's known.
  Future<void> _openManual(String postcode, {String? note}) async {
    setState(() {
      _manual = true;
      _manualNote = note;
      _addresses = const [];
    });
    try {
      final location = await ref
          .read(ukLocationServiceProvider)
          .lookupPostcode(postcode);
      if (!mounted) return;
      if (location == null) {
        setState(() {
          _manual = false;
          _manualNote = null;
          _lookupError = const UnknownPostcodeException().message;
        });
        return;
      }
      if (_form.city.text.trim().isEmpty && location.town != null) {
        _form.city.text = location.town!;
      }
      if (_form.county.text.trim().isEmpty && location.county != null) {
        _form.county.text = location.county!;
      }
    } catch (_) {
      // The town is still typed by hand.
    }
  }

  void _pick(AddressSuggestion address) {
    _form.line1.text = address.line1;
    _form.line2.text = address.line2 ?? '';
    _form.city.text = address.city;
    _form.county.text = address.county ?? '';
    if (address.postcode != null) _form.postcode.text = address.postcode!;
    setState(() {
      _addresses = const [];
      _lookupError = null;
    });
  }

  void _change() => setState(() {
    _clearLines();
    _manual = false;
    _manualNote = null;
  });

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  String? _validatePostcode(String? value) {
    if (!_postcodeFormat.hasMatch(normaliseUkPostcode(value ?? ''))) {
      return 'Enter a full UK postcode, e.g. LS6 3AA.';
    }
    if (!_manual && !_hasAddress) {
      return _addresses.isEmpty
          ? 'Tap Find address, then choose yours.'
          : 'Choose your address from the list.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('address-postcode-field'),
          controller: _form.postcode,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          onChanged: _onPostcodeChanged,
          onFieldSubmitted: (_) => _find(),
          decoration: InputDecoration(
            labelText: 'Postcode',
            hintText: 'e.g. LS6 3AA',
            errorText: widget.postcodeError ?? _lookupError,
            errorMaxLines: 2,
          ),
          validator: _validatePostcode,
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          key: const Key('address-find-button'),
          onPressed: widget.enabled && !_isLookingUp ? _find : null,
          icon: _isLookingUp
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search, size: 18),
          label: const Text('Find address'),
        ),
        if (_addresses.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Choose your address',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Card(
            key: const Key('address-results'),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final address in _addresses)
                    ListTile(
                      key: Key('address-result-${address.id}'),
                      dense: true,
                      leading: const Icon(Icons.home_outlined, size: 20),
                      title: Text([address.line1, ?address.line2].join(', ')),
                      subtitle: Text(address.city),
                      onTap: widget.enabled ? () => _pick(address) : null,
                    ),
                ],
              ),
            ),
          ),
        ],
        if (!_manual && _hasAddress) ...[
          const SizedBox(height: 12),
          Card(
            key: const Key('address-summary'),
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(
                [
                  _form.line1.text.trim(),
                  if (_form.line2.text.trim().isNotEmpty)
                    _form.line2.text.trim(),
                ].join(', '),
              ),
              subtitle: Text(
                [
                  _form.city.text.trim(),
                  if (_form.county.text.trim().isNotEmpty)
                    _form.county.text.trim(),
                  _form.postcode.text.trim(),
                ].join(', '),
              ),
              trailing: TextButton(
                key: const Key('address-change'),
                onPressed: widget.enabled ? _change : null,
                child: const Text('Change'),
              ),
            ),
          ),
        ],
        if (_manual) ...[
          const SizedBox(height: 12),
          if (_manualNote != null) ...[
            Text(
              _manualNote!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            key: const Key('address-line1-field'),
            controller: _form.line1,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Address line 1',
              hintText: 'House number and street',
            ),
            validator: (value) => _required(value, 'Enter the first line.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('address-line2-field'),
            controller: _form.line2,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Address line 2 (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('address-city-field'),
            controller: _form.city,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Town / city'),
            validator: (value) => _required(value, 'Enter your town or city.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('address-county-field'),
            controller: _form.county,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'County (optional)'),
          ),
        ] else if (_addresses.isNotEmpty || !_hasAddress)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('address-manual'),
              onPressed: widget.enabled
                  ? () {
                      final postcode = normaliseUkPostcode(_form.postcode.text);
                      if (_postcodeFormat.hasMatch(postcode)) {
                        _form.postcode.text = postcode;
                        _openManual(postcode);
                      } else {
                        setState(() {
                          _manual = true;
                          _addresses = const [];
                        });
                      }
                    }
                  : null,
              child: Text(
                _addresses.isNotEmpty
                    ? "My address isn't listed"
                    : 'Enter address manually',
              ),
            ),
          ),
        const SizedBox(height: 6),
        const Text(
          'Kept private — other growers only see your town.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
