import 'package:mirit_reminders/core/database/tables/reminders_table.dart';

class Reminder {
  final int? id;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final RecurrenceType recurrenceType;
  final int? categoryId;
  final String? soundPath;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Reminder({
    this.id,
    required this.title,
    this.description,
    required this.scheduledAt,
    this.recurrenceType = RecurrenceType.none,
    this.categoryId,
    this.soundPath,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Reminder copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? scheduledAt,
    RecurrenceType? recurrenceType,
    int? categoryId,
    String? soundPath,
    bool? isActive,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      categoryId: categoryId ?? this.categoryId,
      soundPath: soundPath ?? this.soundPath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
