import 'package:flutter/material.dart';

class GameTool {
  final String id;
  final String title;
  final String description;
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
