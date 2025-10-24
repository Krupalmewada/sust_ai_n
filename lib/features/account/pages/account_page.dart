import 'package:flutter/material.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = Colors.green;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              color: Colors.white,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    child: const Text('A', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Alex',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(Icons.edit, size: 18, color: green),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'imalex97@gmail.com',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu list
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const _MenuCard(children: [
                      _MenuItem(
                        icon: Icons.local_offer_outlined,
                        label: 'My Coupons',
                      ),
                      _MenuItem(
                        icon: Icons.badge_outlined,
                        label: 'My Details',
                      ),
                      _MenuItem(
                        icon: Icons.notifications_none,
                        label: 'Notifications',
                      ),
                      _MenuItem(
                        icon: Icons.help_outline,
                        label: 'Help',
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        label: 'About',
                      ),
                    ]),

                    // Premium upsell
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4EC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.workspace_premium_rounded,
                                color: green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Get more features\nwith Premium',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.tonal(
                                    onPressed: () {},
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      backgroundColor: Colors.white,
                                      foregroundColor: green,
                                      shape: const StadiumBorder(),
                                    ),
                                    child: const Text('Start subscription'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Logout
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.logout_rounded, color: green),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Log Out',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom nav (visual only)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIcon(icon: Icons.home_outlined, onTap: () {}),
              _NavIcon(icon: Icons.restaurant_menu_outlined, onTap: () {}),
              _CenterScanButton(onTap: () {}),
              _NavIcon(icon: Icons.local_offer_outlined, onTap: () {}),
              _NavIcon(icon: Icons.person_outline, onTap: () {}, active: true),
            ],
          ),
        ),
      ),
    );
  }
}

// --- small UI pieces ---

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i != 0) const Divider(height: 1, thickness: .6),
              children[i],
            ]
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {}, // not wired yet
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _NavIcon({required this.icon, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: active ? Colors.green : Colors.black54,
      ),
    );
  }
}

class _CenterScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.crop_free, color: Colors.white),
      ),
    );
  }
}
