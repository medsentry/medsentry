import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../models/user.dart';

/// Standardized, resilient User Avatar component.
/// Safely renders network images, Base64 data URIs, or fallback initials.
class UserAvatar extends StatelessWidget {
  final User? user;
  final String? imageUrl;
  final String? fallbackInitials;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showStatusIndicator;

  const UserAvatar({
    super.key,
    this.user,
    this.imageUrl,
    this.fallbackInitials,
    this.radius = 18,
    this.backgroundColor,
    this.foregroundColor,
    this.showStatusIndicator = false,
  });

  String get _effectiveInitials {
    if (fallbackInitials != null && fallbackInitials!.trim().isNotEmpty) {
      return fallbackInitials!.trim().toUpperCase();
    }
    if (user != null) {
      return user!.initials;
    }
    return 'U';
  }

  String? get _effectiveImageUrl {
    final explicit = imageUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final userUrl = user?.profileImageUrl?.trim();
    if (userUrl != null && userUrl.isNotEmpty) return userUrl;
    return null;
  }

  Uint8List? _tryDecodeBase64(String uri) {
    try {
      final commaIndex = uri.indexOf(',');
      final cleanBase64 = commaIndex != -1 ? uri.substring(commaIndex + 1) : uri;
      return base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }

  Widget _buildFallback(BuildContext context, bool isDark) {
    final bg = backgroundColor ??
        (isDark ? AppColors.primaryEmeraldSubtle : AppColors.primaryEmeraldDeep.withValues(alpha: 0.10));
    final fg = foregroundColor ??
        (isDark ? AppColors.primaryEmerald : AppColors.primaryEmeraldDeep);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.lightBorder,
          width: AppColors.borderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _effectiveInitials,
        style: TextStyle(
          color: fg,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imgUrl = _effectiveImageUrl;

    Widget avatarWidget;

    if (imgUrl == null) {
      avatarWidget = _buildFallback(context, isDark);
    } else if (imgUrl.startsWith('data:image/') || imgUrl.length > 200) {
      final bytes = _tryDecodeBase64(imgUrl);
      if (bytes != null && bytes.isNotEmpty) {
        avatarWidget = Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.border : AppColors.lightBorder,
              width: AppColors.borderWidth,
            ),
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallback(context, isDark),
            ),
          ),
        );
      } else {
        avatarWidget = _buildFallback(context, isDark);
      }
    } else if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
      avatarWidget = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.border : AppColors.lightBorder,
            width: AppColors.borderWidth,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            imgUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallback(context, isDark),
          ),
        ),
      );
    } else {
      avatarWidget = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.border : AppColors.lightBorder,
            width: AppColors.borderWidth,
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            imgUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallback(context, isDark),
          ),
        ),
      );
    }

    if (!showStatusIndicator || user == null) {
      return avatarWidget;
    }

    // Status indicator dot
    final statusColor = !user!.isActive
        ? AppColors.critical
        : (user!.isReactivated ? AppColors.info : AppColors.success);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarWidget,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.55,
            height: radius * 0.55,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.appBackground : Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
