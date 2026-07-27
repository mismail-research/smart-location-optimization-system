import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import 'analysis_results_view.dart';

class AiAnalyzerView extends StatefulWidget {
  final void Function(double lat, double lon, String city)? onViewOnMap;
  final Map<String, dynamic>? initialAnalysisData;
  final Map<String, dynamic>? preSelectedLocation;
  final void Function(String city, String category)? onSelectFromMap;
  final void Function()? onResetSelection;

  const AiAnalyzerView({
    super.key, 
    this.onViewOnMap, 
    this.initialAnalysisData,
    this.preSelectedLocation,
    this.onSelectFromMap,
    this.onResetSelection,
  });

  @override
  State<AiAnalyzerView> createState() => _AiAnalyzerViewState();
}

class _AiAnalyzerViewState extends State<AiAnalyzerView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _currentStep = 0;
  String _selectedBusiness = 'Sports & Fitness';
  double _budgetMin = 30000;
  double _budgetMax = 60000;
  bool _isLoading = false;
  Map<String, dynamic>? _analysisData;
  final TextEditingController _cityController = TextEditingController(text: 'Lahore');

  String _selectedCity = 'Lahore';
  Map<String, dynamic>? _selectedLocationObject;
  List<Map<String, dynamic>> _randomLocations = [];
  bool _isLoadingLocations = false;

  final Map<String, LatLng> _cityCoords = {
    'Lahore': const LatLng(31.5204, 74.3587),
    'Karachi': const LatLng(24.8607, 67.0011),
    'Islamabad': const LatLng(33.6844, 73.0479),
    'Rawalpindi': const LatLng(33.5984, 73.0441),
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialAnalysisData != null) {
      _analysisData = widget.initialAnalysisData;
      _currentStep = 2;
    }
    if (widget.preSelectedLocation != null) {
      _selectedLocationObject = widget.preSelectedLocation;
      _selectedCity = widget.preSelectedLocation!['city'] ?? 'Lahore';
      _cityController.text = _selectedCity;
      _currentStep = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runAnalysisForLocation(widget.preSelectedLocation!);
      });
    } else {
      _loadRandomLocations();
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_currentStep == 2 && _analysisData != null) {
      return AnalysisResultsView(
        analysisData: _analysisData,
        onViewOnMap: () {
          if (widget.onViewOnMap != null && _analysisData != null) {
            widget.onViewOnMap!(
              _analysisData!['lat'],
              _analysisData!['lon'],
              _analysisData!['city'],
            );
          }
        },
        onReset: () {
          setState(() {
            _currentStep = 0;
            _analysisData = null;
            _isLoading = false;
            _selectedLocationObject = null;
          });
          widget.onResetSelection?.call();
          _loadRandomLocations();
        },
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      color: Colors.grey.shade50,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24 : 48, 
              vertical: isMobile ? 32 : 48,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.smart_toy_outlined, color: Colors.blue.shade500, size: 32),
              ),
              const SizedBox(height: 24),
              // Headers
              Text(
                'AI Location Analyzer',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us about your business and we\'ll find the perfect location',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Progress Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressDot(_currentStep >= 0),
                  const SizedBox(width: 8),
                  _buildProgressDot(_currentStep >= 1),
                  const SizedBox(width: 8),
                  _buildProgressDot(_currentStep >= 2),
                ],
              ),
              const SizedBox(height: 48),
                if (_currentStep == 0) 
                  _buildStep1() 
                else 
                  _buildStep2(),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        // Question
        Text(
          'What type of business are you starting?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              // Options Grid
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildOptionCard('Sports & Fitness', Icons.fitness_center),
                  _buildOptionCard('Retail & Shopping', Icons.shopping_bag_outlined),
                  _buildOptionCard('Travel & Lodging', Icons.hotel_outlined),
                  _buildOptionCard('Transportation & Logistics', Icons.local_shipping_outlined),
                ],
              ),
              const SizedBox(height: 48),
              // Continue Button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep = 1;
                      });
                      _loadRandomLocations();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select City',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.location_city_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          items: ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi'].map((city) {
            return DropdownMenuItem(value: city, child: Text(city));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedCity = val;
                _selectedLocationObject = null;
              });
              _loadRandomLocations();
            }
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Select Location',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _showLocationSelectionDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_drop_outlined, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedLocationObject != null 
                              ? _selectedLocationObject!['title']
                              : 'Select Location...',
                          style: GoogleFonts.inter(
                            color: _selectedLocationObject != null ? Colors.black87 : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: IconButton(
                tooltip: 'Select from Map',
                icon: Icon(Icons.map_outlined, color: Colors.blue.shade600),
                onPressed: () {
                  if (widget.onSelectFromMap != null) {
                    widget.onSelectFromMap!(_selectedCity, _selectedBusiness);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'What\'s your monthly rent budget?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 48),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.blue.shade400,
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: Colors.white,
            trackHeight: 8,
            overlayColor: Colors.blue.withValues(alpha: 0.1),
          ),
          child: RangeSlider(
            values: RangeValues(_budgetMin, _budgetMax),
            min: 10000,
            max: 150000,
            divisions: 14,
            onChanged: (RangeValues values) {
              setState(() {
                _budgetMin = values.start;
                _budgetMax = values.end;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PKR ${_budgetMin.toInt().toString().replaceAll(RegExp(r'(?<=\d)(?=(\d\d\d)+(?!\d))'), ',')}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Minimum', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('PKR ${_budgetMax.toInt().toString().replaceAll(RegExp(r'(?<=\d)(?=(\d\d\d)+(?!\d))'), ',')}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Maximum', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade200),
                  backgroundColor: Colors.grey.shade50,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Back',
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: (_isLoading || _selectedLocationObject == null)
                        ? [Colors.grey.shade400, Colors.grey.shade400]
                        : [Colors.blue.shade400, Colors.purple.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: (_isLoading || _selectedLocationObject == null) 
                      ? null 
                      : () => _runAnalysisForLocation(_selectedLocationObject!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressDot(bool isActive) {
    return Container(
      width: 32,
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.shade400 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildOptionCard(String title, IconData icon) {
    final isSelected = _selectedBusiness == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBusiness = title;
        });
      },
      child: Container(
        width: 156,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.blue.shade500 : Colors.black87,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.blue.shade500 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _loadRandomLocations() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocations = true;
      _randomLocations = [];
    });
    
    try {
      final List<Map<String, dynamic>> heatmapPoints = await ApiService.getHeatmapData(_selectedBusiness);
      final List<Map<String, dynamic>> cityPoints = heatmapPoints.where((p) {
        final locality = p['locality']?.toString().toLowerCase() ?? '';
        return locality.contains(_selectedCity.toLowerCase()) || _selectedCity.toLowerCase().contains(locality);
      }).toList();
      
      if (cityPoints.isNotEmpty && mounted) {
        cityPoints.shuffle();
        setState(() {
          _randomLocations = cityPoints.take(5).map((p) {
            return {
              'title': p['name'] ?? '$_selectedBusiness Site',
              'lat': (p['lat'] as num).toDouble(),
              'lon': (p['lng'] as num).toDouble(),
              'city': _selectedCity,
              'category': _selectedBusiness,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading random locations: $e');
    }
    
    // If still empty (or error occurred), generate mock locations
    if (_randomLocations.isEmpty && mounted) {
      final base = _cityCoords[_selectedCity] ?? _cityCoords['Lahore']!;
      final List<String> areas = {
        'Lahore': ['Gulberg', 'DHA Phase 5', 'Model Town', 'Johar Town', 'Faisal Town'],
        'Karachi': ['Clifton', 'DHA Phase 6', 'Gulshan-e-Iqbal', 'North Nazimabad', 'PECHS'],
        'Islamabad': ['Sector F-6', 'Sector F-7', 'Sector G-11', 'Sector I-8', 'Blue Area'],
        'Rawalpindi': ['Saddar', 'Bahria Town Phase 4', 'Satellite Town', 'Chaklala Scheme 3', 'Westridge'],
      }[_selectedCity] ?? ['Center Hub', 'Commercial Zone', 'Business District', 'Main Plaza', 'Elite Street'];

      final Map<String, List<String>> categoryRealNames = {
        'Sports & Fitness': [
          'Powerhouse Gym',
          'FitLife Studio',
          'Titan Fitness Center',
          'Arena MMA & Fitness',
          'Iron & Steel Gym'
        ],
        'Retail & Shopping': [
          'Grand Galleria Mall',
          'Fashion Avenue Boutique',
          'Al-Fatah Superstore',
          'Metro Plaza Shopping',
          'Alpha Electronics Outlet'
        ],
        'Travel & Lodging': [
          'Pearl Continental Hotel',
          'Serena Guest Suites',
          'Ramada Plaza Hotel',
          'Royal Residency Motel',
          'Margalla Hillside Lodge'
        ],
        'Transportation & Logistics': [
          'Daewoo Cargo Terminal',
          'Faisal Express Depot',
          'TCS Courier Hub',
          'Leopard Logistics Center',
          'DHL Express Hub'
        ],
      };

      final names = categoryRealNames[_selectedBusiness] ?? [
        'Premium Business Spot',
        'Commercial Center',
        'Enterprise Plaza',
        'Prime Hub Site',
        'Metro Market Stall'
      ];

      setState(() {
        _randomLocations = List.generate(5, (i) {
          final area = areas[i % areas.length];
          final name = names[i % names.length];
          return {
            'title': '$name ($area)',
            'lat': base.latitude + ((i * 13) % 20 - 10) * 0.002,
            'lon': base.longitude + ((i * 17) % 20 - 10) * 0.002,
            'city': _selectedCity,
            'category': _selectedBusiness,
          };
        });
      });
    }
    
    if (mounted) {
      setState(() {
        _isLoadingLocations = false;
      });
    }
  }

  void _showLocationSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.pin_drop, color: Colors.blue.shade600),
                  const SizedBox(width: 10),
                  Text(
                    'Select Location in $_selectedCity',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: _isLoadingLocations
                  ? Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    )
                  : SizedBox(
                      width: double.maxFinite,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _randomLocations.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final loc = _randomLocations[index];
                          return ListTile(
                            leading: Icon(Icons.location_on_rounded, color: Colors.purple.shade400),
                            title: Text(
                              loc['title'],
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Lat: ${loc['lat'].toStringAsFixed(4)}, Lon: ${loc['lon'].toStringAsFixed(4)}',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedLocationObject = loc;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _runAnalysisForLocation(Map<String, dynamic> location) async {
    setState(() => _isLoading = true);
    final String city = location['city'] ?? _selectedCity;
    final double lat = location['lat'];
    final double lon = location['lon'];

    try {
      final result = await ApiService.getSmartPredict(
        lat: lat,
        lon: lon,
        category: _selectedBusiness,
        city: city,
      );

      if (mounted) {
        if (result != null) {
          result['lat'] = lat;
          result['lon'] = lon;
          result['city'] = city;
          result['title'] = location['title'] ?? 'Selected Location';

          HistoryService.addToHistory({
            'title': 'AI Analysis: $_selectedBusiness in ${location['title'] ?? city}',
            'score': result['suitability_score']?.toInt() ?? 0,
            'type': 'AI Analysis',
            'lat': lat,
            'lon': lon,
            'city': city,
          }, analysisData: result);

          setState(() {
            _analysisData = result;
            _currentStep = 2;
            _isLoading = false;
          });
        } else {
          throw Exception('Empty API response');
        }
      }
    } catch (e) {
      debugPrint('Analysis Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _analysisData = {
            'suitability_score': 65.0, 
            'details': {
              'competitors_within_5km': 2,
              'regional_saturation': 40,
              'detected_category_level1': _selectedBusiness,
              'detected_category_level3': _selectedBusiness,
            },
            'foot_traffic': {'traffic_score': 45.0},
            'is_fallback': true,
          };
          _analysisData!['lat'] = lat;
          _analysisData!['lon'] = lon;
          _analysisData!['city'] = city;
          _analysisData!['title'] = location['title'] ?? 'Selected Location';
          _currentStep = 2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API connection failed. Showing regional estimates for $_selectedBusiness.'),
            backgroundColor: Colors.orange.shade800,
          )
        );
      }
    }
  }
}
