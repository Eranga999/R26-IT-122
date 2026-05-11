// lib/widgets/mode_selector.dart
import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  final String selectedMode;
  final ValueChanged<String> onModeChanged;

  const ModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3A2410),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5C3D1E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTab(
            label: 'Brief',
            icon: Icons.short_text,
            selected: selectedMode == 'brief',
            gold: gold,
            onTap: () => onModeChanged('brief'),
            isFirst: true,
          ),
          _ModeTab(
            label: 'Detail',
            icon: Icons.article_outlined,
            selected: selectedMode == 'detailed',
            gold: gold,
            onTap: () => onModeChanged('detailed'),
            isFirst: false,
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color gold;
  final VoidCallback onTap;
  final bool isFirst;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.gold,
    required this.onTap,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? gold : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isFirst ? 10 : 0),
            bottomLeft: Radius.circular(isFirst ? 10 : 0),
            topRight: Radius.circular(isFirst ? 0 : 10),
            bottomRight: Radius.circular(isFirst ? 0 : 10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? const Color(0xFF1A0E00) : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF1A0E00) : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
