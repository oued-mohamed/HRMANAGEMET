import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../data/models/user_model.dart';

class DashboardHeader extends StatelessWidget {
  final String menuRoute; // '/employee-menu', '/hr-menu', ou '/manager-menu'
  final double titleFontSize;
  final Color titleColor;
  final String? fallbackName;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color backgroundColor;
  final double backgroundOpacity;
  final double borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Widget Function(UserModel?)? buildProfileAvatar;
  final VoidCallback? onProfileTap;
  final Widget? menuButton; // Pour le manager qui a un menu custom

  const DashboardHeader({
    super.key,
    required this.menuRoute,
    this.titleFontSize = 22, // Valeur par défaut comme admin
    this.titleColor = Colors.white, // Valeur par défaut comme admin
    this.fallbackName,
    this.margin,
    this.padding,
    this.backgroundColor = Colors.white,
    this.backgroundOpacity = 0.15, // Valeur par défaut comme admin
    this.borderRadius = 20, // Valeur par défaut comme admin
    this.border,
    this.boxShadow,
    this.buildProfileAvatar,
    this.onProfileTap,
    this.menuButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          margin ?? const EdgeInsets.all(20), // Valeur par défaut comme admin
      padding: padding ??
          const EdgeInsets.symmetric(
              horizontal: 20, vertical: 12), // Valeur par défaut comme admin
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(backgroundOpacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: Colors.white
                  .withOpacity(0.3), // Valeur par défaut comme admin
              width: 1.5, // Valeur par défaut comme admin
            ),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black
                    .withOpacity(0.1), // Valeur par défaut comme admin
                blurRadius: 20, // Valeur par défaut comme admin
                offset: const Offset(0, 10), // Valeur par défaut comme admin
              ),
            ],
      ),
      child: Row(
        children: [
          // Hamburger Menu avec style par défaut comme admin
          menuButton ??
              Container(
                decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.2), // Style par défaut comme admin
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, menuRoute);
                  },
                  icon: Icon(
                    Icons.menu,
                    color: titleColor,
                    size: 26, // Taille par défaut comme admin
                  ),
                ),
              ),
          const SizedBox(width: 16), // Espacement entre menu et titre
          // Title
          Expanded(
            child: StreamBuilder<UserModel?>(
              stream: UserService.instance.userStream,
              initialData: UserService.instance.currentUser,
              builder: (context, userSnapshot) {
                final userName =
                    userSnapshot.data?.name ?? fallbackName ?? 'Utilisateur';
                return Text(
                  'Bonjour $userName',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    letterSpacing: titleFontSize > 20 ? 0.5 : 0,
                  ),
                );
              },
            ),
          ),
          // Profile Picture
          if (buildProfileAvatar != null)
            InkWell(
              onTap: onProfileTap ??
                  () {
                    Navigator.pushNamed(context, '/personal-info');
                  },
              borderRadius: BorderRadius.circular(20),
              child: StreamBuilder<UserModel?>(
                stream: UserService.instance.userStream,
                initialData: UserService.instance.currentUser,
                builder: (context, snapshot) {
                  return buildProfileAvatar!(snapshot.data);
                },
              ),
            ),
        ],
      ),
    );
  }
}
