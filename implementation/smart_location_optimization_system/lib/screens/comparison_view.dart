import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/report_service.dart';
import '../services/comparison_history_service.dart';

class ComparisonView extends StatefulWidget {
  final List<Map<String, dynamic>>? selectedLocations;
  final VoidCallback? onNavigateToMyZoneReports;
  const ComparisonView({super.key, this.selectedLocations, this.onNavigateToMyZoneReports});

  @override
  State<ComparisonView> createState() => _ComparisonViewState();
}

class _ComparisonViewState extends State<ComparisonView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ComparisonHistoryItem? _activeDetailItem;

  String _formatPeakHour(num hour) {
    final hr = hour.toInt();
    if (hr == 0) return '12 AM';
    if (hr == 12) return '12 PM';
    if (hr > 12) return '${hr - 12} PM';
    return '$hr AM';
  }

  double _parseRentToNumericValue(dynamic rentValue) {
    if (rentValue == null) return 50.0;
    String clean = rentValue.toString().trim().toLowerCase();
    
    // Remove currency prefixes
    clean = clean.replaceAll('pkr', '').replaceAll('pr', '').replaceAll('rs', '').trim();
    
    // Remove suffix markers like /mo or /marla
    clean = clean.replaceAll('/mo', '').replaceAll('/marla', '').replaceAll(' ', '').replaceAll(',', '');
    
    double multiplier = 1.0;
    if (clean.endsWith('m')) {
      multiplier = 1000.0; // In thousands, so 22.5M = 22500K
      clean = clean.substring(0, clean.length - 1);
    } else if (clean.endsWith('k')) {
      multiplier = 1.0; // In thousands, so 150K = 150
      clean = clean.substring(0, clean.length - 1);
    } else {
      final rawVal = double.tryParse(clean);
      if (rawVal != null) {
        if (rawVal >= 1000) {
          return rawVal / 1000.0;
        }
        return rawVal;
      }
    }
    
    final val = double.tryParse(clean);
    if (val != null) {
      return val * multiplier;
    }
    return 50.0; // Fallback
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedLocations != null && widget.selectedLocations!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ComparisonHistoryService.addComparison(widget.selectedLocations!);
        if (mounted) {
          setState(() {
            _activeDetailItem = ComparisonHistoryItem(
              id: 'temp',
              title: widget.selectedLocations!.map((loc) => loc['title'] ?? 'Unknown Site').join(' vs '),
              time: 'Just now',
              locations: widget.selectedLocations!,
            );
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return ValueListenableBuilder<List<ComparisonHistoryItem>>(
      valueListenable: ComparisonHistoryService.historyNotifier,
      builder: (context, historyList, child) {
        if (_activeDetailItem == null) {
          return Container(
            color: Colors.grey.shade50,
            padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparison History',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review side-by-side comparisons of candidate locations with date and time',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                if (historyList.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.compare_arrows_rounded,
                              size: 64,
                              color: Colors.purple.shade400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No comparison history yet',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade800,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              'Select 2 or more locations on the Explore Map and click "Compare" to automatically log comparisons here with date & time.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: historyList.length,
                      itemBuilder: (context, index) {
                        final item = historyList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _activeDetailItem = item;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.insights_rounded,
                                      color: Colors.purple.shade600,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade400),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.time,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(Icons.place_outlined, size: 14, color: Colors.grey.shade400),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${item.locations.length} Sites compared',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.grey.shade300,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        }

        final List<Map<String, dynamic>> displayLocations = _activeDetailItem!.locations;
        final List<Color> locationColors = [
          Colors.blue.shade400,
          Colors.green.shade400,
          Colors.orange.shade400,
          Colors.purple.shade400,
          Colors.teal.shade400,
        ];

        return Container(
          color: Colors.grey.shade50,
          padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                if (widget.selectedLocations == null) // Show back button when inside tabs
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _activeDetailItem = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.blue),
                      label: Text(
                        'Back to Comparison History',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ),

                // Header
                isMobile 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compare Locations',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Side-by-side analysis of your selected locations',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Compare Locations',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Side-by-side analysis of your selected locations',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                const SizedBox(height: 32),

                // AI Recommendation Banner (Based on top score)
                if (displayLocations.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.emoji_events, color: Colors.blue.shade600, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Recommendation - Best Pick', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                              Text(displayLocations.first['title'], style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            displayLocations.first['isProperty'] == true
                                ? 'Score: ${displayLocations.first['suitability_score'] ?? "--"}/150'
                                : 'Score: ${displayLocations.first['score']}',
                            style: GoogleFonts.inter(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Comparison Summary Cards
                if (displayLocations.isNotEmpty)
                  isMobile 
                    ? Column(
                        children: displayLocations.asMap().entries.map((entry) {
                          final loc = entry.value;
                          final idx = entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildComparisonCard(
                              title: loc['title'],
                              subtitle: loc['isProperty'] == true 
                                  ? '${loc['scoreLabel'] ?? loc['score'] ?? "Unknown"} Property' 
                                  : 'Location ${String.fromCharCode(65 + idx)}',
                              score: loc['score'],
                              isProperty: loc['isProperty'] == true,
                              suitabilityScore: loc['suitability_score'],
                              metrics: loc['isProperty'] == true
                                  ? {
                                      'Bedrooms': '${loc['traffic'] ?? 0}',
                                      'Foot Traffic': loc['foot_traffic_score'] != null ? '${loc['foot_traffic_score']}%' : '41%',
                                      'Price': loc['price'] ?? loc['rent'] ?? 'PKR 35M',
                                    }
                                  : {
                                      'Traffic Score': (loc['traffic'] ?? 75).toInt(),
                                      'Competitors (5km)': (loc['competition'] ?? 0).toInt(),
                                      'Competitors (Actual)': (loc['competitor_count'] ?? 0).toInt(),
                                      'Rent Affordability': (100 - _parseRentToNumericValue(loc['rent'])).toInt(),
                                      'Average Time Spent': '${(loc['time_spent'] ?? 45).toInt()} mins',
                                      'Weekday Popularity': '${(loc['weekday_avg_popularity'] ?? 60).toInt()}%',
                                      'Weekend Popularity': '${(loc['weekend_avg_popularity'] ?? 75).toInt()}%',
                                      'Morning Traffic': '${(loc['morning_avg'] ?? 40).toInt()}%',
                                      'Afternoon Traffic': '${(loc['afternoon_avg'] ?? 65).toInt()}%',
                                      'Evening Traffic': '${(loc['evening_avg'] ?? 80).toInt()}%',
                                      'Night Traffic': '${(loc['night_avg'] ?? 30).toInt()}%',
                                      'Max Popularity': '${(loc['max_popularity'] ?? 90).toInt()}%',
                                      'Peak Hour': _formatPeakHour(loc['peak_hour'] ?? 18),
                                      'Peak Day': loc['peak_day']?.toString() ?? 'Saturday',
                                    },
                              dotColor: locationColors[idx % locationColors.length],
                            ),
                          );
                        }).toList(),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: displayLocations.asMap().entries.map((entry) {
                            final loc = entry.value;
                            final idx = entry.key;
                            return Container(
                              width: 320,
                              margin: EdgeInsets.only(
                                right: idx == displayLocations.length - 1 ? 0 : 24,
                              ),
                              child: _buildComparisonCard(
                                title: loc['title'],
                                subtitle: loc['isProperty'] == true 
                                    ? '${loc['scoreLabel'] ?? loc['score'] ?? "Unknown"} Property' 
                                    : 'Location ${String.fromCharCode(65 + idx)}',
                                score: loc['score'],
                                isProperty: loc['isProperty'] == true,
                                suitabilityScore: loc['suitability_score'],
                                metrics: loc['isProperty'] == true
                                    ? {
                                        'Bedrooms': '${loc['traffic'] ?? 0}',
                                        'Foot Traffic': loc['foot_traffic_score'] != null ? '${loc['foot_traffic_score']}%' : '41%',
                                        'Price': loc['price'] ?? loc['rent'] ?? 'PKR 35M',
                                      }
                                    : {
                                        'Traffic Score': (loc['traffic'] ?? 75).toInt(),
                                        'Competitors (5km)': (loc['competition'] ?? 0).toInt(),
                                        'Competitors (Actual)': (loc['competitor_count'] ?? 0).toInt(),
                                        'Rent Affordability': (100 - _parseRentToNumericValue(loc['rent'])).toInt(),
                                        'Average Time Spent': '${(loc['time_spent'] ?? 45).toInt()} mins',
                                        'Weekday Popularity': '${(loc['weekday_avg_popularity'] ?? 60).toInt()}%',
                                        'Weekend Popularity': '${(loc['weekend_avg_popularity'] ?? 75).toInt()}%',
                                        'Morning Traffic': '${(loc['morning_avg'] ?? 40).toInt()}%',
                                        'Afternoon Traffic': '${(loc['afternoon_avg'] ?? 65).toInt()}%',
                                        'Evening Traffic': '${(loc['evening_avg'] ?? 80).toInt()}%',
                                        'Night Traffic': '${(loc['night_avg'] ?? 30).toInt()}%',
                                        'Max Popularity': '${(loc['max_popularity'] ?? 90).toInt()}%',
                                        'Peak Hour': _formatPeakHour(loc['peak_hour'] ?? 18),
                                        'Peak Day': loc['peak_day']?.toString() ?? 'Saturday',
                                      },
                                dotColor: locationColors[idx % locationColors.length],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                const SizedBox(height: 32),

                // Radar/Bar breakdown chart
                if (displayLocations.first['isProperty'] != true) ...[
                  isMobile 
                    ? Column(
                        children: [
                          _buildBarChartCard(displayLocations, locationColors),
                          const SizedBox(height: 24),
                          _buildRadarChartCard(displayLocations, locationColors),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildBarChartCard(displayLocations, locationColors)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildRadarChartCard(displayLocations, locationColors)),
                        ],
                      ),
                  const SizedBox(height: 32),
                ],

                // Pros & Cons Section
                if (displayLocations.isNotEmpty && displayLocations.first['isProperty'] != true) ...[
                  isMobile 
                    ? Column(
                        children: displayLocations.asMap().entries.map((entry) {
                          final loc = entry.value;
                          final idx = entry.key;
                          final prosList = [
                            ['High traffic density', 'Strong demographic match', 'Excellent visibility'],
                            ['Optimal rent value', 'Lower local competition', 'Good accessibility'],
                            ['Vibrant commercial area', 'High consumer spend', 'Excellent transport links'],
                            ['Growing neighborhood demand', 'Low entry barriers', 'Ample customer parking'],
                          ];
                          final consList = [
                            ['Higher rent cost', 'Moderate competition levels'],
                            ['Slightly lower footfall', 'Niche demographic concentration'],
                            ['Limited space expansion', 'Higher local tax rates'],
                            ['Varying seasonal traffic', 'Slightly longer commute times'],
                          ];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildProsConsCard(
                              loc['title'],
                              locationColors[idx % locationColors.length],
                              prosList[idx % prosList.length],
                              consList[idx % consList.length],
                            ),
                          );
                        }).toList(),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: displayLocations.asMap().entries.map((entry) {
                            final loc = entry.value;
                            final idx = entry.key;
                            final prosList = [
                              ['High traffic density', 'Strong demographic match', 'Excellent visibility'],
                              ['Optimal rent value', 'Lower local competition', 'Good accessibility'],
                              ['Vibrant commercial area', 'High consumer spend', 'Excellent transport links'],
                              ['Growing neighborhood demand', 'Low entry barriers', 'Ample customer parking'],
                            ];
                            final consList = [
                              ['Higher rent cost', 'Moderate competition levels'],
                              ['Slightly lower footfall', 'Niche demographic concentration'],
                              ['Limited space expansion', 'Higher local tax rates'],
                              ['Varying seasonal traffic', 'Slightly longer commute times'],
                            ];
                            return Container(
                              width: 320,
                              margin: EdgeInsets.only(
                                right: idx == displayLocations.length - 1 ? 0 : 24,
                              ),
                              child: _buildProsConsCard(
                                loc['title'],
                                locationColors[idx % locationColors.length],
                                prosList[idx % prosList.length],
                                consList[idx % consList.length],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  const SizedBox(height: 32),
                ],

                // Generate Report Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade500,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          await ReportService.generateReport(
                            title: displayLocations.length > 1 
                                ? 'Comparison: ${displayLocations.map((loc) => loc['title']).join(' vs ')}'
                                : 'Analysis: ${displayLocations[0]['title']}',
                            type: 'Comparison',
                            locations: displayLocations,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('PDF Report generated and saved to My Zone!'),
                              backgroundColor: Colors.green.shade600,
                              action: SnackBarAction(
                                label: 'VIEW',
                                textColor: Colors.white,
                                onPressed: () {
                                  if (widget.onNavigateToMyZoneReports != null) {
                                    widget.onNavigateToMyZoneReports!();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Generate Report',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required String subtitle,
    required int score,
    required Map<String, dynamic> metrics,
    required Color dotColor,
    bool isProperty = false,
    int? suitabilityScore,
  }) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title, 
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(subtitle, style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isProperty ? 'Suitability Score' : 'Overall Score', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
              Text(
                isProperty 
                    ? '${suitabilityScore ?? score} / 150' 
                    : score.toString(), 
                style: GoogleFonts.inter(color: Colors.green.shade600, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (isProperty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPropertyMetricItem(Icons.bed, metrics['Bedrooms'] ?? '0', 'Bedrooms'),
                _buildPropertyMetricItem(Icons.people, metrics['Foot Traffic'] ?? '0%', 'Foot Traffic'),
                _buildPropertyMetricItem(Icons.attach_money, metrics['Price'] ?? '0', 'Price'),
              ],
            ),
          ] else ...[
            const Divider(height: 32),
            ...metrics.entries.map((e) {
              final val = e.value;
              final valStr = val.toString();
              Color valColor = Colors.grey.shade700;
              
              if (e.key == 'Competitors (5km)' && val is int) {
                valColor = val <= 2 ? Colors.green : (val <= 5 ? Colors.amber.shade700 : Colors.red);
              } else if (val is int) {
                valColor = val >= 80 ? Colors.green : (val >= 60 ? Colors.amber.shade700 : Colors.red);
              } else if (val is String && val.endsWith('%')) {
                final parsed = int.tryParse(val.replaceAll('%', ''));
                if (parsed != null) {
                  valColor = parsed >= 80 ? Colors.green : (parsed >= 60 ? Colors.amber.shade700 : Colors.red);
                }
              } else if (val is String && val.endsWith('mins')) {
                final parsed = int.tryParse(val.replaceAll(' mins', ''));
                if (parsed != null) {
                  valColor = parsed >= 40 ? Colors.green : (parsed >= 20 ? Colors.amber.shade700 : Colors.red);
                }
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: GoogleFonts.inter(fontSize: 12, color: Colors.black87)),
                    Text(valStr, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: valColor)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPropertyMetricItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade500),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartCard(List<Map<String, dynamic>> locations, List<Color> colors) {
    return Container(
      height: 380,
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
              const Icon(Icons.show_chart, size: 20),
              const SizedBox(width: 8),
              Text('Score Breakdown Comparison', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Compare metrics across selected locations', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final titles = ['Traffic', 'Competition', 'Affordability', 'Max Popularity'];
                        if (value.toInt() >= 0 && value.toInt() < titles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(titles[value.toInt()], style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeDynamicGroupData(0, locations, colors, 'traffic'),
                  _makeDynamicGroupData(1, locations, colors, 'competition'),
                  _makeDynamicGroupData(2, locations, colors, 'rent'),
                  _makeDynamicGroupData(3, locations, colors, 'max_popularity'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: locations.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildLegendItem(entry.value['title'], colors[entry.key % colors.length]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChartCard(List<Map<String, dynamic>> locations, List<Color> colors) {
    return Container(
      height: 380,
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
              const Icon(Icons.radar_rounded, size: 20),
              const SizedBox(width: 8),
              Text('Location Fingerprint', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Radar analysis of site properties', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          Expanded(
            child: RadarChart(
              RadarChartData(
                dataSets: locations.asMap().entries.map((entry) {
                  final loc = entry.value;
                  final color = colors[entry.key % colors.length];
                  return RadarDataSet(
                    fillColor: color.withValues(alpha: 0.15),
                    borderColor: color,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: (loc['traffic'] ?? 70).toDouble()),
                      RadarEntry(value: (1.0 - (((loc['competition'] ?? 0) as num).toDouble() / 20.0).clamp(0.0, 1.0)) * 100.0),
                      RadarEntry(value: (100 - _parseRentToNumericValue(loc['rent']))),
                      RadarEntry(value: (loc['max_popularity'] ?? 80).toDouble()),
                    ],
                    borderWidth: 2,
                  );
                }).toList(),
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                tickCount: 4,
                ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
                tickBorderData: const BorderSide(color: Colors.grey),
                gridBorderData: BorderSide(color: Colors.grey.shade300, width: 1),
                getTitle: (index, angle) {
                  final titles = ['Traffic', 'Competition', 'Rent', 'Max Popularity'];
                  return RadarChartTitle(
                    text: titles[index],
                    angle: 0,
                  );
                },
                titleTextStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: locations.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildLegendItem(entry.value['title'], colors[entry.key % colors.length]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProsConsCard(String title, Color dotColor, List<String> pros, List<String> cons) {
    return Container(
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
              Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title, 
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text('Pros', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ...pros.map((p) => _buildBulletPoint(p)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text('Cons', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ...cons.map((c) => _buildBulletPoint(c)),
        ],
      ),
    );
  }

  BarChartGroupData _makeDynamicGroupData(int x, List<Map<String, dynamic>> locations, List<Color> colors, String metricKey) {
    return BarChartGroupData(
      barsSpace: 4,
      x: x,
      barRods: locations.asMap().entries.map((entry) {
        final loc = entry.value;
        final color = colors[entry.key % colors.length];
        
        double val = 0;
        if (metricKey == 'traffic') {
          val = (loc['traffic'] ?? 70).toDouble();
        } else if (metricKey == 'competition') {
          final count = ((loc['competition'] ?? 0) as num).toDouble();
          val = (1.0 - (count / 20.0).clamp(0.0, 1.0)) * 100.0;
        } else if (metricKey == 'rent') {
          val = 100 - _parseRentToNumericValue(loc['rent']);
        } else if (metricKey == 'max_popularity') {
          val = (loc['max_popularity'] ?? 75).toDouble();
        } else {
          val = (loc['score'] ?? 75).toDouble();
          if (val > 100) {
            val = val / 1.5;
          }
        }

        if (val > 100) {
          if (metricKey == 'traffic') {
            val = (val / 100).clamp(0, 100);
          } else {
            val = val.clamp(0, 100);
          }
        } else if (val < 0) {
          val = 0;
        }

        return BarChartRodData(
          toY: val,
          color: color,
          width: 8,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
        );
      }).toList(),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16, height: 1)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
