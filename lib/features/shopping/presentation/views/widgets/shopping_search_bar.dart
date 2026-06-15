import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class ShoppingSearchBar extends StatefulWidget {
  final VoidCallback? onCartPressed;
  final VoidCallback? onBackPressed;
  final int cartItemCount;
  final ValueChanged<String>? onSearch;

  const ShoppingSearchBar({
    super.key,
    this.onCartPressed,
    this.onBackPressed,
    this.cartItemCount = 0,
    this.onSearch,
  });

  @override
  State<ShoppingSearchBar> createState() => _ShoppingSearchBarState();
}

class _ShoppingSearchBarState extends State<ShoppingSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          if (widget.onBackPressed != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: widget.onBackPressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: WunzaColors.premiumText,
            ),
          if (widget.onBackPressed != null) const SizedBox(width: 12),

          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: WunzaColors.premiumSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  widget.onSearch?.call(trimmed);
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search product',
                  hintStyle:
                      const TextStyle(color: WunzaColors.textSecondary),
                  prefixIcon: const Icon(Icons.search,
                      color: WunzaColors.textSecondary),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      return value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: WunzaColors.textSecondary),
                              onPressed: () {
                                _controller.clear();
                                widget.onSearch?.call('');
                              },
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          if (widget.onCartPressed != null) ...[
            const SizedBox(width: 12),
            Stack(
              children: [
                IconButton(
                  onPressed: widget.onCartPressed,
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: WunzaColors.premiumText),
                ),
                if (widget.cartItemCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                          minWidth: 16, minHeight: 16),
                      child: Text(
                        '${widget.cartItemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
