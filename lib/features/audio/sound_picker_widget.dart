import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/features/audio/audio_service.dart';

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
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      widget.onSoundSelected(result.files.single.path);
    }
  }

  Future<void> _previewSound() async {
    await AudioService.instance.playSound(widget.currentSoundPath);
  }

  String _displayName(String? path) {
    if (path == null || path.isEmpty) return 'ברירת מחדל';
    return path.split(RegExp(r'[/\\]')).last;
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomSound =
        widget.currentSoundPath != null && widget.currentSoundPath!.isNotEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.music_note_outlined,
        color: AppColors.primary,
      ),
      title: const Text(AppStrings.sound),
      subtitle: Text(_displayName(widget.currentSoundPath)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasCustomSound)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'הסר צליל',
              onPressed: () => widget.onSoundSelected(null),
            ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'נגן',
            onPressed: _previewSound,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: AppStrings.chooseSound,
            onPressed: _pickFile,
          ),
        ],
      ),
    );
  }
}
