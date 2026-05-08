import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/features/audio/audio_service.dart';
import 'package:mirit_reminders/features/audio/built_in_sounds.dart';

class SoundPickerWidget extends ConsumerStatefulWidget {
  final String? currentSoundPath;
  final void Function(String? path) onSoundSelected;

  const SoundPickerWidget({
    super.key,
    this.currentSoundPath,
    required this.onSoundSelected,
  });

  @override
  ConsumerState<SoundPickerWidget> createState() => _SoundPickerWidgetState();
}

class _SoundPickerWidgetState extends ConsumerState<SoundPickerWidget> {
  Future<void> _showSoundPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SoundPickerSheet(
        currentSound: widget.currentSoundPath,
        onSelected: (path) {
          widget.onSoundSelected(path);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _previewSound() async {
    final path = widget.currentSoundPath;
    if (path == null) return;
    if (builtInSounds.any((s) => s.asset == path)) {
      await AudioService.instance.playAsset(path);
    } else {
      await AudioService.instance.playSound(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSound = widget.currentSoundPath != null &&
        widget.currentSoundPath!.isNotEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.music_note_outlined, color: colorScheme.primary),
      title: const Text(AppStrings.sound),
      subtitle: Text(soundDisplayName(widget.currentSoundPath)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSound)
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'נגן',
              onPressed: _previewSound,
            ),
          if (hasSound)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'הסר צליל',
              onPressed: () => widget.onSoundSelected(null),
            ),
          IconButton(
            icon: const Icon(Icons.library_music_outlined),
            tooltip: AppStrings.chooseSound,
            onPressed: _showSoundPicker,
          ),
        ],
      ),
    );
  }
}

class _SoundPickerSheet extends StatefulWidget {
  final String? currentSound;
  final void Function(String?) onSelected;

  const _SoundPickerSheet({required this.currentSound, required this.onSelected});

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  String? _previewing;

  Future<void> _preview(BuiltInSound sound) async {
    setState(() => _previewing = sound.asset);
    await AudioService.instance.playAsset(sound.asset);
    if (mounted) setState(() => _previewing = null);
  }

  Future<void> _pickCustomFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      widget.onSelected(result.files.single.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Text(AppStrings.chooseSound,
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                // Custom file option
                TextButton.icon(
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('קובץ מהמכשיר'),
                  onPressed: _pickCustomFile,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // None option
          ListTile(
            leading: const Icon(Icons.music_off_outlined),
            title: const Text('ברירת מחדל'),
            selected: widget.currentSound == null,
            selectedColor: colorScheme.primary,
            onTap: () => widget.onSelected(null),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: builtInSounds.length,
              itemBuilder: (_, i) {
                final sound = builtInSounds[i];
                final isSelected = widget.currentSound == sound.asset;
                final isPreviewing = _previewing == sound.asset;

                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(sound.name),
                  trailing: IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isPreviewing
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_circle_outline,
                              key: ValueKey('play')),
                    ),
                    onPressed: isPreviewing ? null : () => _preview(sound),
                  ),
                  selected: isSelected,
                  selectedTileColor:
                      colorScheme.primary.withValues(alpha: 0.08),
                  onTap: () => widget.onSelected(sound.asset),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
