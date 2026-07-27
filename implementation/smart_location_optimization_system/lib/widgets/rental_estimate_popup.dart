import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RentalEstimatePopup extends StatelessWidget {
  final Map<String, dynamic> data;
  final double latitude;
  final double longitude;

  const RentalEstimatePopup({
    super.key,
    required this.data,
    required this.latitude,
    required this.longitude,
  });

  String _formatPKR(double value) {
    final formatter = NumberFormat('#,###');
    return 'PKR ${formatter.format(value)}';
  }

  @override
  Widget build(BuildContext context) {
    final avgRent = (data['avg_rent'] as num?)?.toDouble() ?? 0.0;
    final medianRent = (data['median_rent'] as num?)?.toDouble() ?? 0.0;
    final avgRentPerMarla = (data['avg_rent_per_marla'] as num?)?.toDouble() ?? 0.0;
    final propertiesFound = (data['properties_found'] as num?)?.toInt() ?? 0;
    final dominantType = data['dominant_property_type'] as String? ?? 'Commercial';
    final radius = (data['radius_km'] as num?)?.toDouble() ?? 3.0;
    final source = data['source'] as String? ?? 'nearby';

    String sourceLabel = 'Nearby Listings';
    Color sourceColor = const Color(0xFF6366F1);
    IconData sourceIcon = Icons.location_on_rounded;

    if (source == 'city_fallback') {
      sourceLabel = 'City Fallback';
      sourceColor = const Color(0xFFF59E0B);
      sourceIcon = Icons.location_city_rounded;
    } else if (source == 'overall_fallback') {
      sourceLabel = 'Regional Fallback';
      sourceColor = const Color(0xFFEF4444);
      sourceIcon = Icons.public_rounded;
    }

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
              // Title section with close button
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.monetization_on_rounded,
                        color: sourceColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rental Price Estimate',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
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
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Source Badge row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sourceColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sourceIcon, size: 12, color: sourceColor),
                        const SizedBox(width: 4),
                        Text(
                          sourceLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: sourceColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Average rent highlight
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: 0.06),
                      const Color(0xFF4F46E5).withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatPKR(avgRent),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F46E5),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estimated Average Monthly Rent',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats grid details
              Row(
                children: [
                  _buildDetailCard(
                    icon: Icons.money_rounded,
                    label: 'Rent per Marla',
                    value: _formatPKR(avgRentPerMarla),
                    iconColor: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 10),
                  _buildDetailCard(
                    icon: Icons.analytics_rounded,
                    label: 'Median Rent',
                    value: _formatPKR(medianRent),
                    iconColor: const Color(0xFFF59E0B),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildDetailCard(
                    icon: Icons.store_mall_directory_rounded,
                    label: 'Dominant Property Type',
                    value: dominantType,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 10),
                  _buildDetailCard(
                    icon: Icons.radar_rounded,
                    label: 'Search Radius',
                    value: '${radius.toStringAsFixed(1)} km ($propertiesFound listings)',
                    iconColor: const Color(0xFF0EA5E9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                fontSize: 14,
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
