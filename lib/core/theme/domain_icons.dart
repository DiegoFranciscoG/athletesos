import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Ícono y color reales (Material Icons, sin emoji) por dominio de
/// aprendizaje — usado en onboarding y en la grilla de rutas de Home.
class DomainIcon {
  final IconData icon;
  final Color color;
  const DomainIcon(this.icon, this.color);
}

const domainIcons = <String, DomainIcon>{
  'calistenia': DomainIcon(Icons.accessibility_new_rounded, AppColors.accent),
  'karate': DomainIcon(Icons.sports_martial_arts_rounded, AppColors.onSurface),
  'boxeo': DomainIcon(Icons.sports_mma_rounded, AppColors.coral),
  'ajedrez': DomainIcon(Icons.sports_esports_rounded, AppColors.primary),
};
