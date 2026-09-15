import 'dart:io';

import 'package:flutter/material.dart';
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
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

/// A gear checklist looks great in the reference design, but the backend
/// has no field for it — selecting items is real, visible UI state, it's
/// just not sent anywhere yet ("Coming soon" makes that clear rather than
/// silently discarding it).
const _gearOptions = ['Bypass Shears', 'Mud Boots', 'Grafting Knife', 'Gloves'];

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  EventFormat _format = EventFormat.inPerson;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _coverImage;
  int? _groupId;
  String? _category;
  bool _hasCapacityLimit = true;
  int _capacity = 20;
  final Set<String> _selectedGear = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  DateTime? get _startsAt {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
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
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
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
            capacity: _hasCapacityLimit ? _capacity : null,
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

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(eventsListProvider.notifier)
          .createEvent(
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
            capacity: _hasCapacityLimit ? _capacity : null,
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
        ref.watch(groupsListProvider).valueOrNull?.groups
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
              'AGRO HUB COMMUNITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.primary,
              ),
            ),
            const Text('Create Farming Event'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => _submit(EventStatus.draft),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              backgroundColor: AppColors.surfaceMuted,
              foregroundColor: AppColors.textDark,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: const StadiumBorder(),
            ),
            child: const Text('Save Draft'),
          ),
          const SizedBox(width: 16),
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
                          label: Text('In-Person Field'),
                          icon: Icon(Icons.grass, size: 16),
                        ),
                        ButtonSegment(
                          value: EventFormat.online,
                          label: Text('Online Stream'),
                          icon: Icon(Icons.videocam_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: EventFormat.hybrid,
                          label: Text('Hybrid Meetup'),
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
                        _SectionLabel('Event Cover Photo'),
                        const Spacer(),
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
                      onTap: _isSubmitting ? null : _pickImage,
                    ),
                    const SizedBox(height: 24),
                    _SectionCard(
                      icon: Icons.event_note_outlined,
                      title: 'Event Basics',
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
                        DropdownButtonFormField<int?>(
                          initialValue: _groupId,
                          decoration: const InputDecoration(
                            labelText: 'Publishing Hub / Community Group',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Post to general feed'),
                            ),
                            for (final group in myGroups)
                              DropdownMenuItem(
                                value: group.id,
                                child: Text(
                                  group.membersCount != null
                                      ? '${group.name} (${group.membersCount} members)'
                                      : group.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _groupId = value),
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
                        Row(
                          children: [
                            Expanded(
                              child: _PickerField(
                                label: 'Event Date',
                                value: _selectedDate != null
                                    ? DateFormat(
                                        'MMM d, y',
                                      ).format(_selectedDate!)
                                    : null,
                                onTap: _isSubmitting ? null : _pickDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PickerField(
                                label: 'Start Time',
                                value: _selectedTime?.format(context),
                                onTap: _isSubmitting ? null : _pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Field or Demonstration Address',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ComingSoonToggle(
                          icon: Icons.podcasts_outlined,
                          title: 'Auto-generate Agro Hub Live Stream',
                          subtitle:
                              'Stream live demo to remote group members',
                          onTap: () => _comingSoon('Live streaming'),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _MiniStatBox(
                                label: 'MAX ATTENDEES',
                                child: _hasCapacityLimit
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '$_capacity spots',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          Row(
                                            children: [
                                              _StepperButton(
                                                icon: Icons.remove,
                                                onTap: _capacity > 1
                                                    ? () => setState(
                                                        () => _capacity -= 5,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 6),
                                              _StepperButton(
                                                icon: Icons.add,
                                                onTap: () => setState(
                                                  () => _capacity += 5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : TextButton(
                                        onPressed: () => setState(
                                          () => _hasCapacityLimit = true,
                                        ),
                                        style: TextButton.styleFrom(
                                          minimumSize: Size.zero,
                                          padding: EdgeInsets.zero,
                                          alignment: Alignment.centerLeft,
                                        ),
                                        child: const Text('No limit'),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStatBox(
                                label: 'ADMISSION',
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.mint.withValues(
                                          alpha: 0.35,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          20,
                                        ),
                                      ),
                                      child: const Text(
                                        'Free Event',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () =>
                                            _comingSoon('Paid events'),
                                        style: TextButton.styleFrom(
                                          minimumSize: Size.zero,
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: const Text(
                                          'Set fee',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ComingSoonTagPicker(
                          title: 'Recommended Gear for Participants',
                          options: _gearOptions,
                          selected: _selectedGear,
                          icon: Icons.check_circle_outline,
                          onToggle: (option) => setState(
                            () => _selectedGear.contains(option)
                                ? _selectedGear.remove(option)
                                : _selectedGear.add(option),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _WeatherComingSoonPanel(),
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
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _preview,
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Preview'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
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
                              : const Icon(Icons.eco, size: 18),
                          label: const Text('Publish Event'),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
  const _CoverPhotoPicker({required this.image, required this.onTap});

  final File? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
              : null,
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: image != null ? Colors.black38 : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: image != null
                    ? Colors.white24
                    : AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: image != null ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Change Event Banner',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: image != null ? Colors.white : AppColors.textDark,
                ),
              ),
              Text(
                'PNG, JPG or WebP (up to 8MB)',
                style: TextStyle(
                  fontSize: 12,
                  color: image != null
                      ? Colors.white70
                      : AppColors.textMuted,
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

class _ComingSoonToggle extends StatelessWidget {
  const _ComingSoonToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.forestDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.mint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Coming soon',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: false, onChanged: null),
          ],
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

/// A tappable chip picker for a field the backend doesn't have yet (gear
/// checklist). Selections are real local UI state — visibly checkable,
/// matching the reference design — but the "Coming soon" tag makes clear
/// nothing is sent to the server yet.
class _ComingSoonTagPicker extends StatelessWidget {
  const _ComingSoonTagPicker({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.icon = Icons.check,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Coming soon',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option),
                avatar: selected.contains(option)
                    ? Icon(icon, size: 16, color: Colors.white)
                    : null,
                selected: selected.contains(option),
                onSelected: (_) => onToggle(option),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected.contains(option)
                      ? Colors.white
                      : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                backgroundColor: AppColors.surfaceMuted,
                shape: const StadiumBorder(),
                side: BorderSide.none,
              ),
          ],
        ),
      ],
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.surfaceContainer
              : AppColors.surfaceContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _WeatherComingSoonPanel extends StatelessWidget {
  const _WeatherComingSoonPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forestPanel, AppColors.forestDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wb_cloudy_outlined, color: AppColors.mint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Agri-AI Weather Forecast',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Coming soon',
                        style: TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'A local forecast for your event\'s date and location will '
                  'show here once weather integration ships.',
                  style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
