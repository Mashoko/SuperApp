import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class CategoryPills extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryPills({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1, // +1 for "All" or similar if needed, but assuming categories list has it
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
            // Check if we need to add an "All" option if it's not in the list, 
            // or just use the list as is. 
            // The previous sidebar impl seemed to rely on the generic list.
            // Let's assume the passed list is complete.
            if (index >= categories.length) return const SizedBox.shrink();
            
            final category = categories[index];
            final isSelected = category == selectedCategory;
            
            return GestureDetector(
              onTap: () => onCategorySelected(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? WunzaColors.premiumText : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? WunzaColors.premiumText : WunzaColors.divider,
                  ),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : WunzaColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
        },
      ),
    );
  }
}
