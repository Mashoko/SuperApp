import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/shopping/banner.dart' as model;
import 'package:cached_network_image/cached_network_image.dart';

class PromotionalBanner extends StatelessWidget {
  final model.Banner? banner;

  const PromotionalBanner({
    super.key,
    this.banner,
  });

  @override
  Widget build(BuildContext context) {
    if (banner == null) return const SizedBox.shrink();

    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: WunzaColors.premiumSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image or Color
             Container(
               color: WunzaColors.indigo.withOpacity(0.1),
               width: double.infinity,
               height: double.infinity,
               child: banner!.imageUrl.isNotEmpty 
                 ? CachedNetworkImage(
                     imageUrl: banner!.imageUrl,
                     fit: BoxFit.cover,
                     placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2)),
                     errorWidget: (context, url, error) => const SizedBox(),
                   )
                 : Center(
                   child: Icon(Icons.shopping_bag, size: 48, color: WunzaColors.indigo.withOpacity(0.3)),
                 ),
             ),
             
             // Text Content
             Positioned(
               left: 20,
               bottom: 20,
               right: 20,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(
                     banner!.title,
                     style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                       color: WunzaColors.premiumText,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   const SizedBox(height: 4),
                   Text(
                     banner!.description,
                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                       color: WunzaColors.textSecondary,
                     ),
                   ),
                 ],
               ),
             ),
          ],
        ),
      ),
    );
  }
}
