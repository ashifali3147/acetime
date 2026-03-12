import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../model/user_model.dart';
import '../../repo/auth_repo.dart';
import '../../service/firestore_service.dart';
import '../../style/app_color.dart';
import '../../utils/storage_helper.dart';
import '../navigation/route_names.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<UserModel?> _profileFuture;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<UserModel?> _loadProfile() async {
    final remoteUser = await FirestoreService().getCurrentUserData();
    if (remoteUser != null) {
      StorageHelper().setUserModel(remoteUser);
      if ((remoteUser.userName ?? '').isNotEmpty) {
        StorageHelper().setUserName(remoteUser.userName!);
      }
      return remoteUser;
    }
    return StorageHelper().getUserModel();
  }

  Future<void> _refreshProfile() async {
    final future = _loadProfile();
    setState(() {
      _profileFuture = future;
    });
    await future;
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Do you want to logout from this account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await AuthRepo.logoutApp(
        onLogout: () {
          StorageHelper().clearAllData();
          StorageHelper().setLoginStatus(false);
          AuthRepo.resetEverything();
        },
      );
      if (!mounted) return;
      context.goNamed(RouteNames.login);
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final user = snapshot.data ?? StorageHelper().getUserModel();
        final displayName = (user?.userName?.trim().isNotEmpty ?? false)
            ? user!.userName!.trim()
            : 'Acetime User';
        final phone = (user?.phone?.trim().isNotEmpty ?? false)
            ? user!.phone!.trim()
            : 'Phone number unavailable';
        final createdAt = _formatDate(user?.createdAt);
        final lastLogin = _formatDate(user?.lastLogin);
        final avatarText = displayName.substring(0, 1).toUpperCase();

        return RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE71F83), Color(0xFF6B4EFF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        avatarText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  user == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                _ProfileInfoTile(
                  icon: Icons.badge_outlined,
                  title: 'User ID',
                  value: user?.uid ?? 'Not available',
                ),
                _ProfileInfoTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Joined',
                  value: createdAt,
                ),
                _ProfileInfoTile(
                  icon: Icons.access_time_outlined,
                  title: 'Last login',
                  value: lastLogin,
                ),
                _ProfileInfoTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'FCM token',
                  value: (user?.fcmToken?.isNotEmpty ?? false)
                      ? 'Configured'
                      : 'Not available',
                ),
                _ProfileInfoTile(
                  icon: Icons.phone_iphone_outlined,
                  title: 'VoIP token',
                  value: (user?.voipToken?.isNotEmpty ?? false)
                      ? 'Configured'
                      : 'Not available',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoggingOut ? null : _handleLogout,
                    icon: _isLoggingOut
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.logout, color: Colors.red),
                    label: Text(
                      _isLoggingOut ? 'Logging out...' : 'Logout',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFFFCDD2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (snapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Profile could not be refreshed. Showing saved account data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.hintTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not available';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.themeColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.hintTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.headingColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}