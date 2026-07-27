import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class PropertiesView extends StatefulWidget {
  final Map<String, dynamic>? initialProperty;
  const PropertiesView({super.key, this.initialProperty});

  @override
  State<PropertiesView> createState() => _PropertiesViewState();
}

class _PropertiesViewState extends State<PropertiesView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  String _formatPriceValue(dynamic priceValue) {
    if (priceValue == null) return '0k';
    final str = priceValue.toString().toLowerCase();
    if (str.endsWith('k') || str.endsWith('m')) {
      return priceValue.toString();
    }
    final cleanStr = priceValue.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    final numValue = double.tryParse(cleanStr);
    if (numValue == null) return priceValue.toString();
    String formatted = '';
    if (numValue >= 1000000) {
      final double millions = numValue / 1000000.0;
      formatted = millions == millions.toInt() 
          ? '${millions.toInt()}M' 
          : '${millions.toStringAsFixed(1)}M';
    } else if (numValue >= 1000) {
      final double thousands = numValue / 1000.0;
      formatted = thousands == thousands.toInt() 
          ? '${thousands.toInt()}k' 
          : '${thousands.toStringAsFixed(1)}k';
    } else {
      formatted = numValue == numValue.toInt() ? '${numValue.toInt()}' : numValue.toString();
    }
    if (str.contains('/mo')) {
      formatted += '/mo';
    } else if (str.contains('/marla')) {
      formatted += '/marla';
    }
    return formatted;
  }

  List<Map<String, dynamic>> _properties = [];
  Map<String, dynamic>? _selectedProperty;
  String? _selectedCity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadMasterModelLocations().then((_) {
      if (widget.initialProperty != null) {
        _selectPropertyFromExternal(widget.initialProperty!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PropertiesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProperty != oldWidget.initialProperty && widget.initialProperty != null) {
      _selectPropertyFromExternal(widget.initialProperty!);
    }
  }

  void _selectPropertyFromExternal(Map<String, dynamic> prop) {
    setState(() {
      final index = _properties.indexWhere((p) => p['title'] == prop['title']);
      if (index >= 0) {
        _selectedProperty = _properties[index];
      } else {
        _properties.insert(0, prop);
        _selectedProperty = prop;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(LatLng(prop['lat'], prop['lon']), 14.5);
      }
    });
  }

  Future<void> _loadMasterModelLocations() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> allProperties = [];
      final Map<String, LatLng> cities = {
        'Lahore': const LatLng(31.5204, 74.3587),
        'Karachi': const LatLng(24.8607, 67.0011),
        'Islamabad': const LatLng(33.6844, 73.0479),
        'Rawalpindi': const LatLng(33.5984, 73.0441),
      };

      for (final entry in cities.entries) {
        final cityName = entry.key;
        final coords = entry.value;
        try {
          final cityProps = await ApiService.getProperties(
            lat: coords.latitude,
            lon: coords.longitude,
            radiusKm: 30.0,
            city: cityName,
          );
          for (final p in cityProps) {
            allProperties.add({
              ...p,
              'city_origin': cityName,
            });
          }
        } catch (e) {
          debugPrint('Error fetching properties for $cityName: $e');
        }
      }

      if (allProperties.isNotEmpty) {
        setState(() {
          _properties = allProperties.map((p) {
            final String propertyType = p['property_type'] ?? 'Property';
            final String location = p['location'] ?? 'Unknown Location';
            final String city = p['city'] ?? p['city_origin'] ?? 'Unknown City';
            final String purpose = p['purpose'] ?? 'For Sale';
            final double rawPrice = (p['price'] as num?)?.toDouble() ?? 0.0;
            final int sizeMarla = (p['Area_in_Marla'] as num?)?.toInt() ?? 5;
            
            final String formattedPrice = _formatPriceValue(rawPrice);
            final String title = '$propertyType in $location';
            final String address = '$purpose • $city';
            final String details = '$sizeMarla Marla • $propertyType';
            
            final int score = ((60 + (title.hashCode.abs() % 36)) * 1.5).toInt();

            return {
              'title': title,
              'address': address,
              'lat': (p['latitude'] as num).toDouble(),
              'lon': (p['longitude'] as num).toDouble(),
              'city': city,
              'category': propertyType,
              'price': 'PKR $formattedPrice',
              'details': details,
              'score': score,
              'color': score > 120 ? Colors.green.shade600 : (score >= 75 ? Colors.amber.shade600 : Colors.red.shade600),
              'isProperty': true,
            };
          }).toList();
        });
      } else {
        _loadFallbackLocations();
      }
    } catch (e) {
      _loadFallbackLocations();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadFallbackLocations() {
    final List<Map<String, dynamic>> expandedFallback = [];
    final List<String> categories = ['Retail & Shopping', 'Sports & Fitness', 'Commercial Hub', 'Business Park'];
    final List<String> cities = ['Islamabad', 'Karachi', 'Lahore', 'Rawalpindi'];
    
    final Map<String, LatLng> baseCoords = {
      'Islamabad': const LatLng(33.6844, 73.0479),
      'Karachi': const LatLng(24.8607, 67.0011),
      'Lahore': const LatLng(31.5204, 74.3587),
      'Rawalpindi': const LatLng(33.5984, 73.0441),
    };

    for (final city in cities) {
      final base = baseCoords[city]!;
      for (int i = 1; i <= 10; i++) {
        final double score = 60.0 + (i * 7 + city.hashCode) % 36;
        final String category = categories[(i + city.hashCode) % categories.length];
        expandedFallback.add({
          'title': 'Prime Space $i - $city',
          'address': '$category • $city',
          'lat': base.latitude + ((i * 13) % 20 - 10) * 0.003,
          'lon': base.longitude + ((i * 17) % 20 - 10) * 0.003,
          'city': city,
          'category': category,
          'score': score.toInt(),
        });
      }
    }

    setState(() {
      _properties = expandedFallback.map((loc) {
        final double score = (loc['score'] as num).toDouble() * 1.5;
        final name = loc['title'];
        final int dynamicRent = 95000 + (name.hashCode.abs() % 9) * 10000;
        final String formattedRent = _formatPriceValue(dynamicRent);

        return {
          'title': name,
          'address': loc['address'],
          'lat': loc['lat'],
          'lon': loc['lon'],
          'city': loc['city'],
          'category': loc['category'],
          'price': 'PKR $formattedRent',
          'details': '1500 sq ft • Commercial',
          'score': score.toInt(),
          'color': score > 120 ? Colors.green.shade600 : (score >= 75 ? Colors.amber.shade600 : Colors.red.shade600),
          'isProperty': true,
        };
      }).toList();
      _properties.shuffle();
    });
  }

  List<Map<String, dynamic>> _getFilteredProperties() {
    final query = _searchController.text.trim().toLowerCase();
    return _properties.where((prop) {
      // Filter by selected city first if not null or 'All Cities'
      if (_selectedCity != null && _selectedCity != 'All Cities') {
        final propCity = (prop['city'] ?? '').toString().toLowerCase();
        if (propCity != _selectedCity!.toLowerCase()) {
          return false;
        }
      }
      // Filter by search query
      if (query.isNotEmpty) {
        final title = (prop['title'] ?? '').toString().toLowerCase();
        final address = (prop['address'] ?? '').toString().toLowerCase();
        final category = (prop['category'] ?? '').toString().toLowerCase();
        if (!title.contains(query) && !address.contains(query) && !category.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _predictScore(int index) async {
    final prop = _properties[index];
    setState(() {
      _selectedProperty = prop;
    });
    // Animate map controller to the chosen location with a close-up zoom!
    _mapController.move(LatLng(prop['lat'], prop['lon']), 14.5);

    setState(() => _isLoading = true);

    final result = await ApiService.getSmartPredict(
      lat: prop['lat'],
      lon: prop['lon'],
      category: prop['category'],
      city: prop['city'],
    );

    if (result != null && mounted) {
      setState(() {
        final double rawScore = (result['suitability_score'] as num).toDouble();
        // Scale score to be under 150
        final double score = rawScore.clamp(0.0, 150.0);
        _properties[index]['score'] = score.toInt();
        _properties[index]['color'] = score > 120 ? Colors.green.shade600 : (score >= 75 ? Colors.amber.shade600 : Colors.red.shade600);
        // Update selected property so floating pop-up score refreshes automatically!
        _selectedProperty = _properties[index];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Updated Score for ${prop['title']}')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: isDesktop ? 2 : 1,
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildSearchAndFilter(),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final filtered = _getFilteredProperties();
                          if (filtered.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No matching properties found',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey.shade500,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return _buildPropertyCard(filtered[index]);
                            },
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isDesktop)
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.grey.shade50,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(30.3753, 69.3451),
                          initialZoom: 5.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                          ),
                          if (_selectedProperty != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 80,
                                  height: 80,
                                  point: LatLng(_selectedProperty!['lat'], _selectedProperty!['lon']),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                                          ],
                                        ),
                                        child: Text(
                                          'Score: ${_selectedProperty!['score']}/150',
                                          style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.red,
                                        size: 40,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (_selectedProperty == null)
                        Container(
                          color: Colors.black.withValues(alpha: 0.02),
                          child: Center(
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map_outlined, size: 48, color: Colors.blue.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Select a property and click "Analyze AI"\nto view its exact location',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: Colors.grey.shade700, 
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_selectedProperty != null)
                        Positioned(
                          left: 20,
                          bottom: 20,
                          child: Container(
                            width: 320,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedProperty!['title'],
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                      onPressed: () {
                                        setState(() {
                                          _selectedProperty = null;
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _selectedProperty!['address'],
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SUITABILITY SCORE',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade400,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.trending_up_rounded, color: _selectedProperty!['color'], size: 18),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${_selectedProperty!['score']}/150',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 20,
                                                color: _selectedProperty!['color'],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'ESTIMATED RENT',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade400,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _selectedProperty!['price'],
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 14),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Coordinates: ${_selectedProperty!['lat'].toStringAsFixed(4)}, ${_selectedProperty!['lon'].toStringAsFixed(4)}',
                                          style: GoogleFonts.inter(
                                            color: Colors.blue.shade700,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Properties',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Find the perfect commercial, house, flat, and business locations',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search properties...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Filter by City',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (String city) {
              setState(() {
                _selectedCity = city;
              });
            },
            itemBuilder: (BuildContext context) {
              final List<String> citiesList = ['All Cities', 'Islamabad', 'Karachi', 'Lahore', 'Rawalpindi'];

              return citiesList.map((String city) {
                final isSelected = (_selectedCity == city) || (_selectedCity == null && city == 'All Cities');
                return PopupMenuItem<String>(
                  value: city,
                  child: Row(
                    children: [
                      Icon(
                        city == 'All Cities' ? Icons.location_city_rounded : Icons.location_on_rounded,
                        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          city,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.blue.shade700 : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_rounded, color: Colors.blue.shade600, size: 16),
                    ],
                  ),
                );
              }).toList();
            },
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: _selectedCity != null && _selectedCity != 'All Cities' ? Colors.blue.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedCity != null && _selectedCity != 'All Cities' ? Colors.blue.shade200 : Colors.grey.shade200,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.tune,
                  color: _selectedCity != null && _selectedCity != 'All Cities' ? Colors.blue.shade700 : Colors.grey.shade700,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: property['color'].withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    property['score'].toString(),
                    style: GoogleFonts.inter(
                      color: property['color'],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property['title'],
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 4, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(
                          property['address'],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  ApiService.isFavorite(property)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: ApiService.isFavorite(property)
                      ? Colors.red.shade500
                      : Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    ApiService.toggleFavorite(property);
                  });
                  final isFav = ApiService.isFavorite(property);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isFav
                          ? 'Added to Favorites'
                          : 'Removed from Favorites'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property['price'],
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    property['details'],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildSmallButton('Analyze AI', Colors.blue.shade500, Colors.white, () => _predictScore(_properties.indexOf(property))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(String text, Color bgColor, Color textColor, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: bgColor == Colors.white ? Border.all(color: Colors.grey.shade200) : null,
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
