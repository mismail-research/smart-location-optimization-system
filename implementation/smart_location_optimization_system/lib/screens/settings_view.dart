import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/supabase_config.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _selectedTabIndex = 0;
  
  bool _emailNotifications = true;

  
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: Colors.grey.shade50,
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your account preferences and notifications',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            
            // Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab(0, Icons.notifications_none, 'Notifications'),
                  const SizedBox(width: 16),
                  _buildTab(1, Icons.security, 'Security'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            if (_selectedTabIndex == 0) ...[
              // Notification Channels
              _buildSettingsSection(
                title: 'Notification Channels',
                subtitle: 'Choose how you want to receive notifications',
                children: [
                  _buildToggleItem(
                    'Email Notifications',
                    'Receive updates via email',
                    _emailNotifications,
                    (val) => setState(() => _emailNotifications = val),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Alert Preferences
              _buildSettingsSection(
                title: 'Alert Preferences',
                subtitle: 'Configure what triggers notifications',
                titleSuffix: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Coming Soon',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
                children: [
                  _buildToggleItem(
                    'Price Alerts',
                    'Get notified when prices change in saved areas',
                    false,
                    null,
                  ),
                  const Divider(height: 32),
                  _buildToggleItem(
                    'New Listings',
                    'Alert when new properties match your criteria',
                    false,
                    null,
                  ),
                  const Divider(height: 32),
                  _buildToggleItem(
                    'Weekly Report',
                    'Receive a summary of market trends weekly',
                    false,
                    null,
                  ),
                  const Divider(height: 32),
                  _buildToggleItem(
                    'Marketing & Promotions',
                    'Updates about new features and offers',
                    false,
                    null,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: isMobile ? double.infinity : null,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save All Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ] else if (_selectedTabIndex == 1) ...[
              _buildSecuritySection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.grey.shade300 : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.black87 : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required String subtitle,
    Widget? titleSuffix,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              if (titleSuffix != null) ...[
                const SizedBox(width: 8),
                titleSuffix,
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Colors.blue.shade500,
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    final user = SupabaseAuthService.currentUser;
    final providers = user?.appMetadata?['providers'] as List<dynamic>? ?? [];
    final mainProvider = user?.appMetadata?['provider'] as String?;
    
    final isGoogleUser = (providers.contains('google') || mainProvider == 'google') && !providers.contains('email');

    if (isGoogleUser) {
      return _buildSettingsSection(
        title: 'Change Password',
        subtitle: 'Password management is disabled.',
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'You are signed in with Google. Password changes are managed through your Google account settings.',
                    style: GoogleFonts.inter(color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return _buildSettingsSection(
      title: 'Change Password',
      subtitle: 'Ensure your account is using a long, random password to stay secure.',
      children: [
        _buildPasswordField('New Password', _obscureNew, _newPasswordController, (val) => setState(() => _obscureNew = val)),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _newPasswordController,
          builder: (context, value, child) {
            final password = value.text;
            if (password.isEmpty) return const SizedBox.shrink();

            double strength = 0;
            String label = 'Weak';
            Color color = Colors.red;

            if (password.length >= 8) strength += 0.25;
            if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
            if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
            if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) strength += 0.25;

            if (strength == 1.0) {
              label = 'Excellent';
              color = Colors.green;
            } else if (strength >= 0.5) {
              label = 'Good';
              color = Colors.amber;
            } else {
              label = 'Weak';
              color = Colors.red;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Password strength: $label', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: strength,
                    backgroundColor: Colors.grey.shade200,
                    color: color,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildPasswordField('Confirm New Password', _obscureConfirm, _confirmPasswordController, (val) => setState(() => _obscureConfirm = val)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final newPass = _newPasswordController.text;
              final confirmPass = _confirmPasswordController.text;

              if (newPass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a new password'), backgroundColor: Colors.red),
                );
                return;
              }

              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters long'), backgroundColor: Colors.red),
                );
                return;
              }

              if (newPass != confirmPass) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                final session = SupabaseAuthService.currentSession;
                if (session == null) throw Exception('No active session. Please log in again.');

                final response = await http.post(
                  Uri.parse('http://127.0.0.1:8000/update-password'),
                  headers: {
                    'X-API-KEY': 'my_secure_key_123',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'user_id': session.user.id,
                    'new_password': newPass,
                  }),
                );

                if (response.statusCode >= 200 && response.statusCode < 300) {
                  if (mounted) {
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  throw Exception('HTTP ${response.statusCode}: ${response.body}');
                }
              } catch (e) {
                if (mounted) {
                  String errorMessage = e.toString();
                  if (errorMessage.contains('Failed to fetch') || errorMessage.contains('XMLHttpRequest') || errorMessage.contains('statusCode: null')) {
                    errorMessage = 'Network error or session expired. Please log out completely, log back in, and try again.';
                  } else {
                    errorMessage = 'Failed to update password: $e';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 6)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Change Password',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, bool obscureText, TextEditingController controller, ValueChanged<bool> onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            suffixIcon: IconButton(
              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade500),
              onPressed: () => onToggle(!obscureText),
            ),
          ),
        ),
      ],
    );
  }
}
