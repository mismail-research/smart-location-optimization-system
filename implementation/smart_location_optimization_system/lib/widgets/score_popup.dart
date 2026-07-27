import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

/// A beautiful bottom sheet widget that displays detailed suitability results.
class ScorePopup extends StatefulWidget {
  final SuitabilityResult result;
  final double latitude;
  final double longitude;
  final int siteNumber;
  final VoidCallback? onAiPressed;

  const ScorePopup({
    super.key,
    required this.result,
    required this.latitude,
    required this.longitude,
    required this.siteNumber,
    this.onAiPressed,
  });

  @override
  State<ScorePopup> createState() => _ScorePopupState();
}

class _ScorePopupState extends State<ScorePopup> {
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    final locationData = {
      'title': 'Site ${widget.siteNumber} Analysis',
      'lat': widget.latitude,
      'lon': widget.longitude,
    };
    _isSaved = ApiService.isSavedLocation(locationData);
  }

  /// Returns a gradient color based on the suitability score.
  Color _scoreColor(double score) {
    if (score >= 70) return const Color(0xFF10B981); // Emerald green
    if (score >= 50) return const Color(0xFFF59E0B); // Amber
    if (score >= 30) return const Color(0xFFF97316); // Orange
    return const Color(0xFFEF4444); // Red
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(widget.result.score);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Site title + Close Button row
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.siteNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Site ${widget.siteNumber} Analysis',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, 
                      color: Colors.blue, 
                      size: 22
                    ),
                    tooltip: _isSaved ? 'Remove from My Zone' : 'Save Location',
                    onPressed: () {
                      final locationData = {
                        'title': 'Site ${widget.siteNumber} Analysis',
                        'subtitle': '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
                        'lat': widget.latitude,
                        'lon': widget.longitude,
                        'score': widget.result.score.toInt(),
                        'scoreLabel': 'Suitability Score',
                      };
                      
                      ApiService.toggleSavedLocation(locationData);
                      final isNowSaved = ApiService.isSavedLocation(locationData);
                      
                      setState(() {
                        _isSaved = isNowSaved;
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isNowSaved ? 'Location saved to My Zone' : 'Location removed from My Zone'), 
                          backgroundColor: isNowSaved ? Colors.green : Colors.red,
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Score circle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.06),
                    color.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Score value
                      Column(
                        children: [
                          Text(
                            widget.result.score.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: color,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'out of 150',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Score label
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Suitability Score',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'AI Predicted Location Rank',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.onAiPressed != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6366F1), // Indigo
                            Color(0xFF8B5CF6), // Purple
                            Color(0xFFEC4899), // Pink
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onAiPressed,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Detailed AI Analyzer',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Detail cards
            Row(
              children: [
                _buildDetailCard(
                  icon: Icons.storefront_rounded,
                  label: 'Competitors (5km)',
                  value: '${widget.result.competitors}',
                  iconColor: const Color(0xFF6366F1),
                ),
                const SizedBox(width: 10),
                _buildDetailCard(
                  icon: Icons.area_chart_rounded,
                  label: 'Regional Saturation',
                  value: '${widget.result.regionalSaturation}',
                  iconColor: const Color(0xFF8B5CF6),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildDetailCard(
                  icon: Icons.category_rounded,
                  label: 'Category (L1)',
                  value: widget.result.level1Category,
                  iconColor: const Color(0xFF0EA5E9),
                ),
                const SizedBox(width: 10),
                _buildDetailCard(
                  icon: Icons.sell_rounded,
                  label: 'Category (L3)',
                  value: widget.result.level3Category,
                  iconColor: const Color(0xFF14B8A6),
                ),
              ],
            ),
            if (widget.result.footTraffic != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildDetailCard(
                    icon: Icons.directions_walk_rounded,
                    label: 'Traffic Score',
                    value: formatCompactNumber(widget.result.footTraffic!['traffic_score'] ?? 0),
                    iconColor: const Color(0xFFF43F5E),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ],
        ),
      ),
    ));
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
