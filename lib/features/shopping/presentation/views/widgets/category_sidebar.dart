import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/shared/widgets/glass_container.dart';

class CategorySidebar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategorySidebar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: GlassContainer(
        opacity: 0.3,
        borderRadius: 0, // Sidebar doesn't need partial radius usually, or maybe just top-right/bottom-right
        child: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          // Map category to icon and color (Mocking colorful icons)
          IconData iconData;
          Color iconColor;
          switch (category) {
            case 'Popular':
              iconData = Icons.trending_up;
              iconColor = WunzaColors.primary;
              break;
            case 'Produce':
              iconData = Icons.local_grocery_store;
              iconColor = Colors.green;
              break;
            case 'Butcher':
              iconData = Icons.kebab_dining;
              iconColor = Colors.red;
              break;
            case 'Bakery':
              iconData = Icons.bakery_dining;
              iconColor = Colors.brown;
              break;
            case 'Staples':
              iconData = Icons.rice_bowl;
              iconColor = Colors.blueGrey;
              break;
            case 'Dairy':
              iconData = Icons.local_pizza;
              iconColor = Colors.amber;
              break;
            case 'Infants':
              iconData = Icons.child_care;
              iconColor = Colors.pinkAccent;
              break;
            case 'Beverages':
              iconData = Icons.local_drink;
              iconColor = Colors.blue;
              break;
            case 'Household':
              iconData = Icons.cleaning_services;
              iconColor = Colors.purple;
              break;
            case 'Snacks':
              iconData = Icons.fastfood;
              iconColor = Colors.orange;
              break;
            case 'Sanitary':
              iconData = Icons.soap;
              iconColor = Colors.cyan;
              break;
            case 'Pets':
              iconData = Icons.pets;
              iconColor = Colors.brown[400]!;
              break;
            default:
              iconData = Icons.category;
              iconColor = Colors.grey;
          }

          return GestureDetector(
            onTap: () => onCategorySelected(category),
            child: Container(
              color: isSelected ? Colors.white : Colors.transparent,
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        color: WunzaColors.primary,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12), // Larger padding
                          decoration: BoxDecoration(
                            color: isSelected ? iconColor.withValues(alpha: 0.1) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData,
                            color: iconColor,
                            size: 32, // Larger icon
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: WunzaColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12, // Larger text
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}
