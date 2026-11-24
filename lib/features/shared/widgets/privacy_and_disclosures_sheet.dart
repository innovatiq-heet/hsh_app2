import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal bottom sheet presenting all sensitive institutional disclosures
/// (App Blocker, Curfew Geofence, Data Sharing & Privacy Policy)
/// in full compliance with Google Play Prominent Disclosure & User Data policies.
class PrivacyAndDisclosuresSheet extends StatelessWidget {
  const PrivacyAndDisclosuresSheet({super.key});

  static const String privacyPolicyUrl =
      'https://lightcoral-eel-306042.hostingersite.com/privacy-policy';

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PrivacyAndDisclosuresSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF0284C7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRIVACY & DISCLOSURES',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0284C7),
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Permissions & User Data Policy',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  const Text(
                    'HSH Connect is the official institutional hostel companion for residents of Hari Saurabh Hostel (AVD VVN). '
                    'To ensure student academic focus, curfew discipline, and resident safety, specific Android system capabilities are requested with prominent in-app disclosure.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 1: App blocker (Usage access + Display over other apps)
                  const _DisclosureCard(
                    icon: Icons.shield_rounded,
                    iconColor: Color(0xFF0284C7),
                    badgeText: 'CORE REQUIREMENT',
                    badgeColor: Color(0xFFD97706),
                    title: 'App Blocker Disclosure',
                    body:
                        'HSH Connect uses Usage access to see which app is open and how long each app is used, and Display over other apps to show the block screen over an app restricted by the hostel. '
                        'Daily app usage and blocked-app events (app name, time, reason) are sent to the hostel server. '
                        'HSH Connect also becomes a device admin app, with your consent, so it can\'t be force-stopped or uninstalled while you are signed in; it uses no admin powers and is removed when you log out. Attempts to turn it off while signed in are blocked and reported to the hostel. '
                        'HSH Connect does not use the Accessibility service and does not read screen content, messages or keystrokes.',
                  ),
                  const SizedBox(height: 14),

                  // Card 2: Curfew Location Tracking
                  const _DisclosureCard(
                    icon: Icons.my_location_rounded,
                    iconColor: Color(0xFF059669),
                    badgeText: 'SAFETY & CURFEW',
                    badgeColor: Color(0xFF059669),
                    title: 'Background Location Disclosure',
                    body:
                        'For active hostel residents, location is periodically collected all day—including when the app is closed or in the background—strictly to verify campus curfew compliance and warden-issued gate passes.\n\n'
                        '• The curfew geofence NEVER locks a resident\'s phone.\n'
                        '• Location data is never used for advertising, tracking outside hostel policy, or sold to third parties.',
                  ),
                  const SizedBox(height: 14),

                  // Card 3: Data Protection & Deletion
                  const _DisclosureCard(
                    icon: Icons.lock_outline_rounded,
                    iconColor: Color(0xFF6366F1),
                    badgeText: 'DATA GUARANTEE',
                    badgeColor: Color(0xFF6366F1),
                    title: 'Data Privacy & Deletion Requests',
                    body:
                        'All resident telemetry is encrypted via HTTPS/TLS and strictly role-gated. All monitoring stops immediately when a student signs out or becomes an alumni.\n\n'
                        'You may request account or personal data deletion at any time by emailing krutarthsolanki9@gmail.com.',
                  ),
                  const SizedBox(height: 20),

                  // Live Privacy Policy Button
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(privacyPolicyUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                    label: const Text(
                      'Read Full Hosted Privacy Policy (Web)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

class _DisclosureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String badgeText;
  final Color badgeColor;
  final String title;
  final String body;

  const _DisclosureCard({
    required this.icon,
    required this.iconColor,
    required this.badgeText,
    required this.badgeColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
