import 'package:mirit_reminders/core/database/tables/reminders_table.dart';

/// Sentinel used by [Reminder.copyWith] to distinguish "argument not provided"
/// from "argument provided as null". Without this, callers cannot clear an
/// existing description / categoryId / soundPath / completedAt because
/// `x ?? this.x` always falls back to the existing value when null is passed.
const Object _unset = Object();

class Reminder {
  final int? id;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final RecurrenceType recurrenceType;
  final int? categoryId;
  final String? soundPath;
  final bool isActive;
  // null = not done yet. For one-shot reminders, non-null hides them from
  // upcoming and stops them firing. For recurring reminders it's a "last
  // completion" marker used by the stats screen.
  final DateTime? completedAt;
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
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isCompletedOneShot =>
      completedAt != null && recurrenceType == RecurrenceType.none;

  Reminder copyWith({
    int? id,
    String? title,
    Object? description = _unset,
    DateTime? scheduledAt,
    RecurrenceType? recurrenceType,
    Object? categoryId = _unset,
    Object? soundPath = _unset,
    bool? isActive,
    Object? completedAt = _unset,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as int?,
      soundPath: identical(soundPath, _unset)
          ? this.soundPath
          : soundPath as String?,
      isActive: isActive ?? this.isActive,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
