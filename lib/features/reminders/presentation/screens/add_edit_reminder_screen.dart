import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
import 'package:mirit_reminders/features/audio/sound_picker_widget.dart';
import 'package:mirit_reminders/features/categories/presentation/providers/categories_provider.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:mirit_reminders/features/reminders/presentation/providers/reminders_provider.dart';

class AddEditReminderScreen extends ConsumerStatefulWidget {
  final Reminder? reminder;

  const AddEditReminderScreen({super.key, this.reminder});

  @override
  ConsumerState<AddEditReminderScreen> createState() =>
      _AddEditReminderScreenState();
}

class _AddEditReminderScreenState extends ConsumerState<AddEditReminderScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late RecurrenceType _recurrenceType;
  int? _categoryId;
  String? _soundPath;

  bool get _isEditMode => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    if (r != null) {
      _titleController = TextEditingController(text: r.title);
      _descriptionController = TextEditingController(text: r.description ?? '');
      _selectedDate = r.scheduledAt;
      _selectedTime = TimeOfDay(
        hour: r.scheduledAt.hour,
        minute: r.scheduledAt.minute,
      );
      _recurrenceType = r.recurrenceType;
      _categoryId = r.categoryId;
      _soundPath = r.soundPath;
    } else {
      final defaultTime = DateTime.now().add(const Duration(hours: 1));
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _selectedDate = defaultTime;
      _selectedTime = TimeOfDay(
        hour: defaultTime.hour,
        minute: defaultTime.minute,
      );
      _recurrenceType = RecurrenceType.none;
      _categoryId = null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final reminder = Reminder(
      id: widget.reminder?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      scheduledAt: scheduledAt,
      recurrenceType: _recurrenceType,
      categoryId: _categoryId,
      soundPath: _soundPath,
      isActive: widget.reminder?.isActive ?? true,
      createdAt: widget.reminder?.createdAt,
    );

    final notifier = ref.read(remindersNotifierProvider.notifier);
    if (_isEditMode) {
      await notifier.update(reminder);
    } else {
      await notifier.add(reminder);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deleteReminder),
        content: const Text(AppStrings.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text(AppStrings.deleteReminder),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(remindersNotifierProvider.notifier)
          .delete(widget.reminder!.id!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return '$d/$m/$y';
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _recurrenceLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return AppStrings.once;
      case RecurrenceType.daily:
        return AppStrings.daily;
      case RecurrenceType.monthly:
        return AppStrings.monthly;
      case RecurrenceType.yearly:
        return AppStrings.yearly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? AppStrings.editReminder : AppStrings.addReminder,
        ),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: AppStrings.deleteReminder,
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: AppStrings.title,
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'נא למלא כותרת' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: AppStrings.description,
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // Date & Time row
            Row(
              children: [
                Expanded(
                  child: _TappableField(
                    label: AppStrings.date,
                    value: _formatDate(_selectedDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TappableField(
                    label: AppStrings.time,
                    value: _formatTime(_selectedTime),
                    icon: Icons.access_time_outlined,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recurrence
            DropdownButtonFormField<RecurrenceType>(
              initialValue: _recurrenceType,
              decoration: const InputDecoration(
                labelText: AppStrings.recurrence,
                border: OutlineInputBorder(),
              ),
              items: RecurrenceType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(_recurrenceLabel(t)),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _recurrenceType = v);
              },
            ),
            const SizedBox(height: 16),

            // Category
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: AppStrings.category,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text('ללא קטגוריה'),
                    ),
                  ),
                  ...categories.map(
                    (cat) => DropdownMenuItem<int?>(
                      value: cat.id,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(cat.name),
                          const SizedBox(width: 8),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: cat.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),

            // Sound picker
            SoundPickerWidget(
              currentSoundPath: _soundPath,
              onSoundSelected: (path) => setState(() => _soundPath = path),
            ),
          ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                AppStrings.save,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TappableField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _TappableField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(icon, size: 20),
        ),
        child: Text(
          value,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
