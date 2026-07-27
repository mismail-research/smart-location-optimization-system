import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_auth_service.dart';
import '../services/user_data_sync_service.dart';
import '../services/api_service.dart';
import '../services/report_service.dart';
import '../services/history_service.dart';
import '../services/comparison_history_service.dart';
import 'login_screen.dart';
import 'landing_screen.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class ProfileView extends StatefulWidget {
  final bool isGuest;
  final VoidCallback? onViewSavedLocations;

  const ProfileView({
    super.key,
    this.isGuest = false,
    this.onViewSavedLocations,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isUpdatingAvatar = false;
  String? _localAvatarUrl;

  final List<Map<String, String>> _avatarPresets = [
    {
      'gender': 'Men',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80',
    },
    {
      'gender': 'Men',
      'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80',
    },
    {
      'gender': 'Men',
      'url': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=150&q=80',
    },
    {
      'gender': 'Women',
      'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
    },
    {
      'gender': 'Women',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
    },
    {
      'gender': 'Women',
      'url': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=150&q=80',
    },
  ];

  Future<void> _updateAvatar(String url) async {
    setState(() {
      _isUpdatingAvatar = true;
    });
    try {
      await SupabaseAuthService.updateUserAvatar(url);
      setState(() {
        _localAvatarUrl = url;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture updated successfully!', style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvatar = false;
        });
      }
    }
  }

  Future<void> _pickLocalImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        
        if (bytes != null) {
          final base64String = base64Encode(bytes);
          final extension = file.extension ?? 'png';
          final dataUrl = 'data:image/$extension;base64,$base64String';
          await _updateAvatar(dataUrl);
        } else {
          throw 'Could not read file bytes.';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAvatarUploadDialog() {
    int selectedPresetIndex = 0;
    final PageController presetPageController = PageController(
      initialPage: 0,
      viewportFraction: 0.4,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 24,
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 440,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.photo_camera_rounded, color: Colors.purple.shade700, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Update Profile Picture',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SWIPE TO SELECT PRESET AVATAR',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3 Men • 3 Women',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Swipeable presets carousel
                    SizedBox(
                      height: 130,
                      child: PageView.builder(
                        controller: presetPageController,
                        itemCount: _avatarPresets.length,
                        onPageChanged: (int index) {
                          setDialogState(() {
                            selectedPresetIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = _avatarPresets[index];
                          final url = item['url']!;
                          final gender = item['gender']!;
                          final isSelected = selectedPresetIndex == index;
                          
                          return AnimatedScale(
                            scale: isSelected ? 1.0 : 0.8,
                            duration: const Duration(milliseconds: 200),
                            child: AnimatedOpacity(
                              opacity: isSelected ? 1.0 : 0.5,
                              duration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                onTap: () {
                                  presetPageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  setDialogState(() {
                                    selectedPresetIndex = index;
                                  });
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.purple.shade500
                                              : Colors.grey.shade200,
                                          width: isSelected ? 3.5 : 1.5,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.purple.withValues(alpha: 0.15),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: ClipOval(
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.person, size: 40, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: gender == 'Men'
                                            ? Colors.blue.shade50
                                            : Colors.pink.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        gender,
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: gender == 'Men'
                                              ? Colors.blue.shade700
                                              : Colors.pink.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    // Center select button for the swiped preset
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final selectedUrl = _avatarPresets[selectedPresetIndex]['url']!;
                          Navigator.pop(context);
                          _updateAvatar(selectedUrl);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: Text(
                          'Save Selected Preset',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'UPLOAD FROM YOUR DEVICE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickLocalImage();
                        },
                        icon: Icon(Icons.upload_file_rounded, color: Colors.purple.shade700),
                        label: Text(
                          'Browse Image Files',
                          style: GoogleFonts.inter(color: Colors.purple.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.purple.shade200, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.isGuest) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'You are using Guest Mode',
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in or create an account to view and manage your profile.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.login),
              label: Text('Sign In', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      color: Colors.grey.shade50,
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header Profile Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: isMobile 
                ? Column(
                    children: [
                      _buildProfileAvatar(),
                      const SizedBox(height: 24),
                      _buildProfileInfo(true),
                    ],
                  )
                : Row(
                    children: [
                      _buildProfileAvatar(),
                      const SizedBox(width: 24),
                      Expanded(child: _buildProfileInfo(false)),
                    ],
                  ),
            ),
            const SizedBox(height: 24),

            // Stats Cards
            AnimatedBuilder(
              animation: Listenable.merge([
                ApiService.savedLocationsNotifier,
                ReportService.reportsNotifier,
                HistoryService.historyNotifier,
                ComparisonHistoryService.historyNotifier,
              ]),
              builder: (context, _) {
                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildStatCard(ApiService.savedLocationsNotifier.value.length.toString(), 'Saved Locations', isMobile),
                    _buildStatCard(ReportService.reportsNotifier.value.length.toString(), 'Reports Generated', isMobile),
                    _buildStatCard(HistoryService.historyNotifier.value.length.toString(), 'Properties Viewed', isMobile),
                    _buildStatCard(ComparisonHistoryService.historyNotifier.value.length.toString(), 'Comparisons Made', isMobile),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Personal Information
            Builder(
              builder: (context) {
                final String fullName = SupabaseAuthService.currentUserName;
                final List<String> parts = fullName.split(' ');
                final String firstName = parts.isNotEmpty ? parts[0] : fullName;

                return _buildInfoSection(
                  title: 'Personal Information',
                  subtitle: 'Your personal and contact details',
                  isMobile: isMobile,
                  children: [
                    if (isMobile) ...[
                      _buildDataField('First Name', firstName),
                      const SizedBox(height: 24),
                      _buildDataField('Email Address', SupabaseAuthService.currentUserEmail ?? 'No Email', icon: Icons.email_outlined),
                    ] else
                      Row(
                        children: [
                          Expanded(child: _buildDataField('First Name', firstName)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildDataField('Email Address', SupabaseAuthService.currentUserEmail ?? 'No Email', icon: Icons.email_outlined)),
                        ],
                      ),
                  ],
                );
              }
            ),
            const SizedBox(height: 24),

            // Quick Actions
            _buildInfoSection(
              title: 'Quick Actions',
              subtitle: 'Common actions for your account',
              isMobile: isMobile,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildActionButton(context, 'View My Saved Locations'),
                    _buildActionButton(context, 'Log Out'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final avatarUrl = _localAvatarUrl ?? SupabaseAuthService.currentUserAvatar;
    return GestureDetector(
      onTap: _showAvatarUploadDialog,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: Stack(
            children: [
              Center(
                child: _isUpdatingAvatar
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
                      )
                    : ClipOval(
                        child: avatarUrl != null
                            ? _buildAvatarImage(avatarUrl, 80)
                            : const Icon(Icons.person, size: 40, color: Colors.grey),
                      ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String url, double size) {
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return Icon(Icons.person, size: size / 2, color: Colors.grey);
      }
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.person, size: size / 2, color: Colors.grey),
    );
  }

  Widget _buildProfileInfo(bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Text(SupabaseAuthService.currentUserName, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildInfoTag(Icons.calendar_today_outlined, SupabaseAuthService.currentUserJoinedDate),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTag(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, bool isMobile) {
    return Container(
      width: isMobile ? (MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).size.width - 72) / 2 : 180,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade500)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildInfoSection({required String title, required String subtitle, required bool isMobile, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDataField(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.black87),
              const SizedBox(width: 8),
            ],
            Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 12),
        Text(value, style: GoogleFonts.inter(fontSize: 14, color: Colors.black87)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label) {
    final isLogout = label == 'Log Out';
    return OutlinedButton(
      onPressed: () async {
        if (isLogout) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Log Out'),
              content: const Text('Are you sure you want to log out of your account?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Log Out'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            try {
              await SupabaseAuthService.signOut();
            } catch (e) {
              debugPrint('Logout: Error during signOut: $e');
            }
            UserDataSyncService.clearUserData();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_guest', false);
            
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LandingScreen()),
                (route) => false,
              );
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          }
        } else {
          if (label == 'View My Saved Locations' && widget.onViewSavedLocations != null) {
            widget.onViewSavedLocations!();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Action: $label initiated')),
            );
          }
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: isLogout ? Colors.red.shade200 : Colors.grey.shade300),
        foregroundColor: isLogout ? Colors.red : null,
      ),
      child: Text(
        label, 
        style: GoogleFonts.inter(
          color: isLogout ? Colors.red.shade700 : Colors.black87, 
          fontWeight: FontWeight.w600, 
          fontSize: 12
        )
      ),
    );
  }
}
