import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  static bool isNarrow(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  // Column count for grid layouts
  static int gridColumns(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 ? 2 : 1;
}
