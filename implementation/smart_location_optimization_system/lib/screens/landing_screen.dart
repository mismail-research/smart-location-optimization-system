import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/loca_logo.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: ClipRect(
          child: Stack(
            children: [
            // Background gradient meshes
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.pink.shade100.withValues(alpha: 0.5),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -100,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.shade100.withValues(alpha: 0.4),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ColorFilter.mode(
                  Colors.white.withValues(alpha: 0.2),
                  BlendMode.dstATop,
                ),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            // Main Content
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              children: [
                                const SizedBox(height: 40),
                                _buildHeroText(context),
                                const SizedBox(height: 24),
                                Container(
                                  constraints: const BoxConstraints(maxWidth: 700),
                                  child: Text(
                                    'AI-powered location intelligence that analyzes foot traffic, competition, and property metrics to give you data-driven recommendations',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: screenWidth > 600 ? 16 : 14,
                                      color: Colors.grey.shade600,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => const SignupScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Text(
                                        'Start Free',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 60),
                                _buildFeaturesGrid(context),
                                const SizedBox(height: 60),
                                _buildBottomCTA(context),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildFooter(context),
                  ],
                ),
              ),
            ),
          ],
        ),
       ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;

    final Widget logoArea = const LocaLogo(scale: 0.8);
    final Widget buttonsArea = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const LoginScreen()),
            );
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey.shade400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            'Log In',
            style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.purple.shade400],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SignupScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Get Started',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: isMobile
          ? Column(
              children: [
                logoArea,
                const SizedBox(height: 16),
                buttonsArea,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                logoArea,
                buttonsArea,
              ],
            ),
    );
  }

  Widget _buildHeroText(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double fontSize = screenWidth > 900
        ? 48
        : (screenWidth > 600 ? 38 : (screenWidth > 360 ? 28 : 22));

    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            height: 1.25,
          ),
          children: [
            const TextSpan(text: 'Find the '),
            TextSpan(
              text: 'Perfect ',
              style: TextStyle(color: Colors.red.shade600),
            ),
            TextSpan(
              text: 'Location ',
              style: TextStyle(color: Colors.blue.shade700),
            ),
            const TextSpan(text: 'for Your Business'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double cardWidth;
    double cardHeight;

    if (screenWidth > 1100) {
      cardWidth = 240;
      cardHeight = 220;
    } else if (screenWidth > 800) {
      cardWidth = 220;
      cardHeight = 240;
    } else if (screenWidth > 600) {
      cardWidth = 250;
      cardHeight = 220;
    } else {
      cardWidth = (screenWidth - 48).clamp(280.0, 500.0);
      cardHeight = 140;
    }

    final isMobileLayout = screenWidth <= 600;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _buildFeatureCard(
          icon: Icons.location_on_outlined,
          title: 'Smart Location Analysis',
          description: 'AI-powered insights to find the perfect spot for your business.',
          color: Colors.purple.shade100,
          width: cardWidth,
          height: cardHeight,
          isMobileLayout: isMobileLayout,
        ),
        _buildFeatureCard(
          icon: Icons.show_chart,
          title: 'Foot Traffic Data',
          description: 'Real-time pedestrian flow analytics and heatmaps.',
          color: Colors.blue.shade100,
          width: cardWidth,
          height: cardHeight,
          isMobileLayout: isMobileLayout,
        ),
        _buildFeatureCard(
          icon: Icons.store_outlined,
          title: 'Property Listings',
          description: 'Curated commercial spaces matched to your needs.',
          color: Colors.pink.shade100,
          width: cardWidth,
          height: cardHeight,
          isMobileLayout: isMobileLayout,
        ),
        _buildFeatureCard(
          icon: Icons.analytics_outlined,
          title: 'Predictive Analytics',
          description: 'Suitability scores powered by machine learning.',
          color: Colors.orange.shade100,
          width: cardWidth,
          height: cardHeight,
          isMobileLayout: isMobileLayout,
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required double width,
    required double height,
    required bool isMobileLayout,
  }) {
    final cardContent = isMobileLayout
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.blue.shade700, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.blue.shade700, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          );

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: cardContent,
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Ready to find your ideal location?',
            style: GoogleFonts.inter(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Join thousands of entrepreneurs making smarter location decisions with Loca.ai',
            style: GoogleFonts.inter(
              fontSize: isMobile ? 12 : 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade500],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Start Free Click Here',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;

    final Widget copyrightText = Text(
      '© 2024 Loca.ai. All rights reserved.',
      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
      textAlign: TextAlign.center,
    );

    final Widget footerLinks = Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      children: [
        Text('Privacy', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
        Text('Terms', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
        Text('Contact', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: isMobile
          ? Column(
              children: [
                footerLinks,
                const SizedBox(height: 12),
                copyrightText,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                copyrightText,
                footerLinks,
              ],
            ),
    );
  }
}
