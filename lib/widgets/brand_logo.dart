import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// The Kitagawa India wordmark.
///
/// Always sized by width: the asset is a wide 3.8:1 mark, so constraining its
/// height would make it tiny. It is also drawn on an explicit white card
/// because the JPEG has an opaque white background — on any tinted surface an
/// unpadded logo would show as a visible white rectangle with a hard edge.
class BrandLogo extends StatelessWidget {
  final double width;
  final EdgeInsetsGeometry padding;
  final bool framed;

  const BrandLogo({
    super.key,
    this.width = AppSizes.logoWidthLogin,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      AppAssets.logo,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Kitagawa India',
    );

    if (!framed) return image;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: image,
    );
  }
}
