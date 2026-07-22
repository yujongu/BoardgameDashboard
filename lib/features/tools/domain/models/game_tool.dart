import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class GameTool {
  final String id;

  /// Resolvers so the title/description can be localized at build time — the
  /// registry is a top-level constant built without a BuildContext.
  final String Function(AppStrings) title;
  final String Function(AppStrings) description;
  final IconData icon;
  final WidgetBuilder destinationBuilder;

  GameTool({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.destinationBuilder,
  });
}
