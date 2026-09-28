import 'package:flutter/material.dart';

/// A badge shown on the Profile screen. Earned automatically from stats
/// the app already tracks — nothing extra is saved.
class GardenBadge {
  const GardenBadge({
    required this.name,
    required this.howToEarn,
    required this.icon,
    required this.earned,
  });

  final String name;
  final String howToEarn;
  final IconData icon;
  final bool earned;
}

/// All badges, in the order they appear. To add one: add a line here.
List<GardenBadge> badgesFor({
  required int completedSessions,
  required int harvestedPlants,
  required int streak,
  required int gardenLevel,
}) {
  return [
    GardenBadge(
      name: 'First Sprout',
      howToEarn: 'Finish your first focus session.',
      icon: Icons.eco,
      earned: completedSessions >= 1,
    ),
    GardenBadge(
      name: 'Focused Five',
      howToEarn: 'Finish 5 focus sessions.',
      icon: Icons.timer,
      earned: completedSessions >= 5,
    ),
    GardenBadge(
      name: 'Green Thumb',
      howToEarn: 'Grow your first plant all the way.',
      icon: Icons.local_florist,
      earned: harvestedPlants >= 1,
    ),
    GardenBadge(
      name: 'On a Roll',
      howToEarn: 'Finish 3 sessions in a row without giving up.',
      icon: Icons.local_fire_department,
      earned: streak >= 3,
    ),
    GardenBadge(
      name: 'Bouquet',
      howToEarn: 'Grow 5 plants.',
      icon: Icons.spa,
      earned: harvestedPlants >= 5,
    ),
    GardenBadge(
      name: 'Garden Keeper',
      howToEarn: 'Reach garden level 5.',
      icon: Icons.star,
      earned: gardenLevel >= 5,
    ),
  ];
}
