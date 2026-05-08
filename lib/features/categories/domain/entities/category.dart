import 'package:flutter/material.dart';

class Category {
  final int? id;
  final String name;
  final String colorHex;
  final String iconName;
  final bool isPreset;

  const Category({
    this.id,
    required this.name,
    required this.colorHex,
    required this.iconName,
    this.isPreset = false,
  });

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  IconData get icon => _iconMap[iconName] ?? Icons.label;

  static const Map<String, IconData> _iconMap = {
    'work': Icons.work,
    'family_restroom': Icons.family_restroom,
    'favorite': Icons.favorite,
    'groups': Icons.groups,
    'label': Icons.label,
    'star': Icons.star,
    'home': Icons.home,
    'school': Icons.school,
    'fitness_center': Icons.fitness_center,
    'shopping_cart': Icons.shopping_cart,
    // Added per client request — birthday/celebration/gift etc.
    'cake': Icons.cake,
    'celebration': Icons.celebration,
    'card_giftcard': Icons.card_giftcard,
    'medical_services': Icons.medical_services,
    'medication': Icons.medication,
    'pets': Icons.pets,
    'restaurant': Icons.restaurant,
    'flight': Icons.flight,
    'directions_car': Icons.directions_car,
    'savings': Icons.savings,
    'event_note': Icons.event_note,
    'alarm': Icons.alarm,
    'phone': Icons.phone,
    'email': Icons.email,
    'church': Icons.church,
    'menorah': Icons.auto_awesome,
    'spa': Icons.spa,
    'local_florist': Icons.local_florist,
    'beach_access': Icons.beach_access,
    'book': Icons.menu_book,
  };

  Category copyWith({
    int? id,
    String? name,
    String? colorHex,
    String? iconName,
    bool? isPreset,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      isPreset: isPreset ?? this.isPreset,
    );
  }
}
