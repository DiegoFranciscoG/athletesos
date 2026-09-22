import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  static const List<String> _routes = ['/', '/ajustes'];
  static const List<String> _labels = ['Aprender', 'Ajustes'];

  static IconData _iconFor(int index) {
    switch (index) {
      case 0: return Icons.school_rounded;
      case 1: return Icons.tune_rounded;
      default: return Icons.circle;
    }
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _routes.length; i++) {
      if (location == _routes[i]) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 0,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.4),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: List.generate(_labels.length, (index) {
              final isSelected = index == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => context.go(_routes[index]),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _iconFor(index),
                          size: 22,
                          color: isSelected ? AppColors.primary : AppColors.neutralSecondary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _labels[index],
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.neutralSecondary,
                            letterSpacing: isSelected ? 0.04 : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
