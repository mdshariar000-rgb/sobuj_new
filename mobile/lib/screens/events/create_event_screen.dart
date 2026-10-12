import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';
import '../../models/event_enums.dart';
import '../../providers/auth_providers.dart';
import '../../providers/event_providers.dart';
import '../../providers/group_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import 'event_detail_screen.dart';

/// A dedicated screen (matching the Figma "Create Event" frame) rather than
/// a bottom sheet — enough fields that a sheet would feel cramped, and it
/// mirrors "Save Draft" as its own explicit action alongside Publish.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key, this.event});

  /// An event of yours to edit — a draft from "My drafts" to finish, or a
  /// published one from its detail page.
  final Event? event;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _feeController = TextEditingController();
  final List<DateTime> _proposedDates = [];

  EventFormat _format = EventFormat.inPerson;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  TimeOfDay? _selectedEndTime;
  File? _coverImage;
  int? _groupId;
  String? _category;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final draft = widget.event;
    if (draft == null) return;
    // Event times are stored and shown as entered (no UTC conversion), so
    // read the wall-clock fields as they are — toLocal() would shift them.
    final startsAt = draft.startsAt;
    final endsAt = draft.endsAt;
    _titleController.text = draft.title;
    _descriptionController.text = draft.description ?? '';
    _locationController.text = draft.location ?? '';
    _capacityController.text = draft.capacity?.toString() ?? '';
    _feeController.text = draft.registrationFee != null
        ? draft.registrationFee!.toStringAsFixed(2)
        : '';
    _proposedDates.addAll(draft.proposedDates.map((date) => date.toLocal()));
    _format = draft.format;
    _category = draft.category;
    _groupId = draft.groupId;
    _selectedDate = DateTime(startsAt.year, startsAt.month, startsAt.day);
    _selectedTime = TimeOfDay.fromDateTime(startsAt);
    if (endsAt != null) _selectedEndTime = TimeOfDay.fromDateTime(endsAt);
  }

  /// Editing an event that's already live — it saves in place instead of
  /// offering Save Draft / Publish.
  bool get _isEditingPublished => widget.event?.status == EventStatus.published;

  /// Empty or zero means a free event.
  double? get _registrationFee {
    final fee = double.tryParse(_feeController.text.trim());
    return fee == null || fee <= 0 ? null : fee;
  }

  /// Empty means no attendee limit.
  int? get _capacity => int.tryParse(_capacityController.text.trim());

  DateTime? get _startsAt {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// On the event's date; an end time at or before the start runs past
  /// midnight into the next day.
  DateTime? get _endsAt {
    final start = _startsAt;
    final time = _selectedEndTime;
    if (start == null || time == null) return null;
    final end = DateTime(
      start.year,
      start.month,
      start.day,
      time.hour,
      time.minute,
    );
    return end.isAfter(start) ? end : end.add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _coverImage = File(picked.path));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await _showTimeWheel(
      'Start time',
      _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _pickEndTime() async {
    final start = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
    final time = await _showTimeWheel(
      'End time',
      _selectedEndTime ??
          TimeOfDay(hour: (start.hour + 2) % 24, minute: start.minute),
    );
    if (time != null) setState(() => _selectedEndTime = time);
  }

  /// Another date the host is considering — a date, then a time.
  Future<void> _addProposedDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await _showTimeWheel(
      'Time',
      _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;
    setState(
      () => _proposedDates
        ..add(DateTime(date.year, date.month, date.day, time.hour, time.minute))
        ..sort(),
    );
  }

  /// A scrolling hour/minute wheel — simpler to use than the clock dial.
  Future<TimeOfDay?> _showTimeWheel(String title, TimeOfDay initial) {
    var picked = initial;
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('event-time-done'),
                    onPressed: () => Navigator.of(context).pop(picked),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                minuteInterval: 5,
                initialDateTime: DateTime(
                  2000,
                  1,
                  1,
                  picked.hour,
                  picked.minute - picked.minute % 5,
                ),
                onDateTimeChanged: (value) =>
                    picked = TimeOfDay.fromDateTime(value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _preview() {
    final currentUser = ref.read(authControllerProvider).valueOrNull;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: Event(
            id: -1,
            groupId: _groupId,
            title: _titleController.text.trim().isEmpty
                ? 'Untitled event'
                : _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            format: _format,
            category: _category,
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            startsAt: _startsAt ?? DateTime.now().add(const Duration(days: 1)),
            endsAt: _endsAt,
            coverImageUrl: widget.event?.coverImageUrl,
            capacity: _capacity,
            registrationFee: _registrationFee,
            proposedDates: _proposedDates,
            status: EventStatus.draft,
            host: currentUser,
            createdAt: DateTime.now(),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(EventStatus status) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startsAt == null) {
      setState(() => _errorMessage = 'Pick a date and time for the event.');
      return;
    }
    if (status == EventStatus.published && _endsAt == null) {
      setState(() => _errorMessage = 'Pick an end time for the event.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(eventsListProvider.notifier)
          .createEvent(
            existingEventId: widget.event?.id,
            groupId: _groupId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            format: _format,
            category: _category,
            coverImage: _coverImage,
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            startsAt: _startsAt!,
            endsAt: _endsAt,
            capacity: _capacity,
            registrationFee: _registrationFee,
            proposedDates: _proposedDates,
            status: status,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myGroups =
        ref
            .watch(groupsListProvider)
            .valueOrNull
            ?.groups
            .where((group) => group.isMember == true)
            .toList() ??
        const [];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SHOBUJ COMMUNITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.primary,
              ),
            ),
            Text(widget.event != null ? 'Edit Event' : 'Create Event'),
          ],
        ),
        actions: [
          if (!_isEditingPublished) ...[
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _submit(EventStatus.draft),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                backgroundColor: AppColors.surfaceMuted,
                foregroundColor: AppColors.textDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: const StadiumBorder(),
              ),
              child: const Text('Save Draft'),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        _SectionLabel('Event Format'),
                        const Spacer(),
                        Text(
                          'Select one',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<EventFormat>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: EventFormat.inPerson,
                          label: Text('In-Person'),
                          icon: Icon(Icons.grass, size: 16),
                        ),
                        ButtonSegment(
                          value: EventFormat.online,
                          label: Text('Online'),
                          icon: Icon(Icons.videocam_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: EventFormat.hybrid,
                          label: Text('Hybrid'),
                          icon: Icon(Icons.sync_alt, size: 16),
                        ),
                      ],
                      selected: {_format},
                      onSelectionChanged: (value) =>
                          setState(() => _format = value.first),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _SectionLabel('Event Cover Photo')),
                        const SizedBox(width: 8),
                        Text(
                          '16:9 recommended',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _CoverPhotoPicker(
                      image: _coverImage,
                      imageUrl: widget.event?.coverImageUrl,
                      onTap: _isSubmitting ? null : _pickImage,
                    ),
                    const SizedBox(height: 24),
                    _SectionCard(
                      icon: Icons.event_note_outlined,
                      title: 'Event Information',
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Event Title *',
                            hintText: 'Meyer Lemon Pruning & Grafting Workshop',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Enter a title.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) => DropdownMenu<int?>(
                            key: const Key('event-group-picker'),
                            width: constraints.maxWidth,
                            initialSelection: _groupId,
                            label: const Text('Group (optional)'),
                            hintText: 'Search your groups',
                            leadingIcon: const Icon(Icons.search),
                            enableFilter: true,
                            requestFocusOnTap: true,
                            menuHeight: 280,
                            dropdownMenuEntries: [
                              const DropdownMenuEntry(
                                value: null,
                                label: 'No group',
                              ),
                              for (final group in myGroups)
                                DropdownMenuEntry(
                                  value: group.id,
                                  label: group.name,
                                ),
                            ],
                            onSelected: (value) =>
                                setState(() => _groupId = value),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _CategoryPicker(
                          selected: _category,
                          isSubmitting: _isSubmitting,
                          onSelected: (category) =>
                              setState(() => _category = category),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      icon: Icons.schedule_outlined,
                      title: 'Schedule & Location',
                      children: [
                        _PickerField(
                          label: 'Event Date',
                          value: _selectedDate != null
                              ? DateFormat('EEE d MMM y').format(_selectedDate!)
                              : null,
                          onTap: _isSubmitting ? null : _pickDate,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _PickerField(
                                label: 'Start Time',
                                value: _selectedTime?.format(context),
                                onTap: _isSubmitting ? null : _pickTime,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PickerField(
                                key: const Key('event-end-time'),
                                label: 'End Time',
                                value: _selectedEndTime?.format(context),
                                onTap: _isSubmitting ? null : _pickEndTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Address of Event',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Proposed dates (optional)',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Other dates you are considering for this event.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final date in _proposedDates)
                              InputChip(
                                label: Text(
                                  DateFormat('EEE d MMM · HH:mm').format(date),
                                ),
                                onDeleted: _isSubmitting
                                    ? null
                                    : () => setState(
                                        () => _proposedDates.remove(date),
                                      ),
                              ),
                            ActionChip(
                              key: const Key('add-proposed-date'),
                              avatar: const Icon(Icons.add, size: 18),
                              label: const Text('Add date'),
                              onPressed: _isSubmitting
                                  ? null
                                  : _addProposedDate,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      icon: Icons.checklist_outlined,
                      title: 'Details & Registration',
                      children: [
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Event Description & Tools Required',
                            hintText:
                                'Join us for hands-on grafting and pruning '
                                'practice — bring sanitized shears if you '
                                'have them.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('event-capacity-field'),
                          controller: _capacityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Max attendees',
                            hintText: 'Leave empty for no limit',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('event-fee-field'),
                          controller: _feeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Registration fee (£)',
                            hintText: 'Leave empty for a free event',
                            helperText: 'Paid at the event, not in the app.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _preview,
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Preview'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submit(EventStatus.published),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _isEditingPublished ? Icons.check : Icons.eco,
                                  size: 18,
                                ),
                          label: Text(
                            _isEditingPublished
                                ? 'Save Changes'
                                : 'Publish Event',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CoverPhotoPicker extends StatelessWidget {
  const _CoverPhotoPicker({
    required this.image,
    required this.imageUrl,
    required this.onTap,
  });

  final File? image;

  /// The event's current cover, shown until a new one is picked.
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null || imageUrl != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          image: image != null
              ? DecorationImage(image: FileImage(image!), fit: BoxFit.cover)
              : imageUrl != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: hasImage ? Colors.black38 : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: hasImage
                    ? Colors.white24
                    : AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: hasImage ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasImage ? 'Change Event Banner' : 'Upload Event Banner',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: hasImage ? Colors.white : AppColors.textDark,
                ),
              ),
              Text(
                'PNG, JPG or WebP (up to 8MB)',
                style: TextStyle(
                  fontSize: 12,
                  color: hasImage ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value ?? 'Select',
          style: TextStyle(
            color: value != null ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// The real, admin-managed event category picker (see EventCategory on the
/// backend) — single-select, tap a chip again to clear it. Backs the same
/// list the Events tab's filter chips read from, so an admin adding or
/// renaming a category shows up here with no app update needed.
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({
    required this.selected,
    required this.isSubmitting,
    required this.onSelected,
  });

  final String? selected;
  final bool isSubmitting;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(eventCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Category',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        categoriesAsync.when(
          loading: () => const SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          // Fail open: an event can still be created without picking a
          // category if the admin-managed list can't be fetched.
          error: (error, _) => const SizedBox.shrink(),
          data: (categories) {
            if (categories.isEmpty) return const SizedBox.shrink();
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  ChoiceChip(
                    label: Text(category.name),
                    selected: selected == category.name,
                    onSelected: isSubmitting
                        ? null
                        : (isSelected) =>
                              onSelected(isSelected ? category.name : null),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected == category.name
                          ? Colors.white
                          : AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.surfaceMuted,
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
