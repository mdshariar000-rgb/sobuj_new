import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/enums.dart';
import '../../../models/swap_offer.dart';
import '../../../theme/app_colors.dart';

/// The deal strip under the listing in a marketplace chat: where the deal
/// stands, and the one or two things this person can do about it right now
/// (accept/decline, mark as sold/swapped, cancel). The server enforces who
/// may do what — see SwapOfferPolicy::respond() — this only offers the
/// buttons that make sense for each side.
class DealBar extends StatelessWidget {
  const DealBar({
    super.key,
    required this.swapOffer,
    required this.isSeller,
    required this.onUpdateStatus,
  });

  final SwapOffer swapOffer;
  final bool isSeller;
  final Future<void> Function(SwapOfferStatus status, {int? quantitySold})
  onUpdateStatus;

  bool get _isSwap =>
      swapOffer.listing?.transactionType == TransactionType.swap;

  String get _doneVerb => _isSwap ? 'swapped' : 'sold';

  String get _buyerName => swapOffer.requester?.name ?? 'The buyer';

  String get _sellerName => swapOffer.listing?.owner?.name ?? 'The seller';

  Future<void> _complete(BuildContext context) async {
    final quantity = swapOffer.listing?.quantity;

    int? quantitySold;
    if (isSeller && quantity != null && quantity > 1) {
      quantitySold = await showDialog<int>(
        context: context,
        builder: (_) => _QuantitySoldDialog(available: quantity),
      );
      if (quantitySold == null) return;
    } else {
      final confirmed = await _confirm(
        context,
        title: isSeller
            ? 'Mark as $_doneVerb?'
            : 'Mark as ${_isSwap ? 'swapped' : 'received'}?',
        message: isSeller
            ? 'Only do this once you have handed it over to $_buyerName.'
            : 'Only do this once you have it from $_sellerName.',
        action: 'Yes, done',
      );
      if (!confirmed) return;
    }
    await onUpdateStatus(SwapOfferStatus.completed, quantitySold: quantitySold);
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Cancel this deal?',
      message: 'The other person will be told it\'s off.',
      action: 'Cancel deal',
      destructive: true,
    );
    if (confirmed) await onUpdateStatus(SwapOfferStatus.canceled);
  }

  Future<void> _decline(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Decline $_buyerName?',
      message: 'They will be told you can\'t go ahead with this one.',
      action: 'Decline',
      destructive: true,
    );
    if (confirmed) await onUpdateStatus(SwapOfferStatus.declined);
  }

  @override
  Widget build(BuildContext context) {
    final status = swapOffer.status;

    final (IconData icon, String text, List<Widget> actions) = switch (status) {
      SwapOfferStatus.pending when isSeller => (
        Icons.handshake_outlined,
        '$_buyerName wants this. Agree the details in chat, then accept.',
        [
          _secondary('Decline', () => _decline(context), 'deal-decline'),
          _primary(
            'Accept',
            () => onUpdateStatus(SwapOfferStatus.accepted),
            'deal-accept',
          ),
        ],
      ),
      SwapOfferStatus.pending => (
        Icons.hourglass_empty,
        'Waiting for $_sellerName to accept.',
        [_secondary('Cancel', () => _cancel(context), 'deal-cancel')],
      ),
      SwapOfferStatus.countered when !isSeller => (
        Icons.handshake_outlined,
        '$_sellerName suggested different terms.',
        [
          _secondary(
            'Decline',
            () => onUpdateStatus(SwapOfferStatus.declined),
            'deal-decline',
          ),
          _primary(
            'Accept',
            () => onUpdateStatus(SwapOfferStatus.accepted),
            'deal-accept',
          ),
        ],
      ),
      SwapOfferStatus.countered => (
        Icons.hourglass_empty,
        'Waiting for $_buyerName to reply to your terms.',
        [_secondary('Cancel', () => _cancel(context), 'deal-cancel')],
      ),
      SwapOfferStatus.accepted => (
        Icons.check_circle_outline,
        'Deal agreed. Meet up, hand it over, then mark it done.',
        [
          _secondary('Cancel', () => _cancel(context), 'deal-cancel'),
          _primary(
            isSeller
                ? 'Mark as $_doneVerb'
                : (_isSwap ? 'Mark as swapped' : 'Mark as received'),
            () => _complete(context),
            'deal-complete',
          ),
        ],
      ),
      SwapOfferStatus.completed => (
        Icons.verified,
        'Deal done.',
        const <Widget>[],
      ),
      SwapOfferStatus.declined => (
        Icons.block,
        'This deal was declined.',
        const <Widget>[],
      ),
      SwapOfferStatus.canceled => (
        Icons.close,
        'This deal was cancelled.',
        const <Widget>[],
      ),
    };

    final isOpen = status.isOpen;

    return Container(
      key: const Key('deal-bar'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.mintLight : AppColors.surfaceMuted,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isOpen ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _primary(String label, VoidCallback onTap, String key) => FilledButton(
    key: Key(key),
    onPressed: onTap,
    style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
    child: Text(label),
  );

  Widget _secondary(String label, VoidCallback onTap, String key) =>
      OutlinedButton(
        key: Key(key),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          foregroundColor: AppColors.textDark,
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surfaceContainer,
        ),
        child: Text(label),
      );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          key: const Key('deal-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? AppColors.error : AppColors.primary,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// "How many were sold?" — asked when the seller completes a deal on a
/// listing with more than one unit. Returns the number, or null if they
/// back out.
class _QuantitySoldDialog extends StatefulWidget {
  const _QuantitySoldDialog({required this.available});

  final int available;

  @override
  State<_QuantitySoldDialog> createState() => _QuantitySoldDialogState();
}

class _QuantitySoldDialogState extends State<_QuantitySoldDialog> {
  final _controller = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 1 || value > widget.available) {
      setState(() => _error = 'Enter a number from 1 to ${widget.available}.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('How many were sold?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.available} available. The listing stays up until '
            'they are all gone.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('deal-quantity-sold'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Quantity sold',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        TextButton(
          key: const Key('deal-quantity-confirm'),
          onPressed: _submit,
          child: const Text('Mark as sold'),
        ),
      ],
    );
  }
}
