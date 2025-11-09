import 'package:flutter/material.dart';

/// User profile card inspired by Zapya's profile section
class UserProfileCard extends StatelessWidget {
  final String? userName;
  final String? userAvatar;
  final bool isLoggedIn;
  final int fansCount;
  final int followCount;
  final VoidCallback? onLoginTap;
  final VoidCallback? onMessageTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCardTap;

  const UserProfileCard({
    super.key,
    this.userName,
    this.userAvatar,
    this.isLoggedIn = false,
    this.fansCount = 0,
    this.followCount = 0,
    this.onLoginTap,
    this.onMessageTap,
    this.onSettingsTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE53E3E), // Primary red
            Color(0xFF9F7AEA), // Purple accent
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Add user icon
                GestureDetector(
                  onTap: onLoginTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (onMessageTap != null)
                      IconButton(
                        onPressed: onMessageTap,
                        icon: const Icon(
                          Icons.message_outlined,
                          color: Colors.white,
                        ),
                      ),
                    if (onSettingsTap != null)
                      IconButton(
                        onPressed: onSettingsTap,
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // User info section
            Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: onLoginTap,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: userAvatar != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.network(
                              userAvatar!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildDefaultAvatar(),
                            ),
                          )
                        : _buildDefaultAvatar(),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // User details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLoggedIn && userName != null) ...[
                        Text(
                          userName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Connected',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: onLoginTap,
                          child: const Text(
                            'Click to Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Currently not logged in',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Card icon
                if (onCardTap != null)
                  GestureDetector(
                    onTap: onCardTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.grid_view,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Stats section
            Row(
              children: [
                _buildStatItem('Fans', fansCount),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _buildStatItem('Follow', followCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.grey,
        size: 30,
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
