import 'package:flutter/material.dart';

import '../../domain/models/map_scope.dart';

/// The horizontal option bar under the search field. Picking an option decides
/// both the blue radius drawn around the pointer and which alerts are loaded.
class ScopeFilterBar extends StatelessWidget {
  final MapScope selected;
  final ValueChanged<MapScope> onSelected;
  final bool isResolving;

  const ScopeFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.isResolving = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: MapScope.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final scope = MapScope.values[index];
          final isSelected = scope == selected;
          final busy = isSelected && isResolving;

          return Material(
            color: isSelected ? const Color(0xFF1A73E8) : Colors.white,
            elevation: 3,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => onSelected(scope),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      Icon(
                        scope.icon,
                        size: 18,
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                    const SizedBox(width: 8),
                    Text(
                      scope.chipLabel,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[900],
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
