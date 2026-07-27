import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loca_logo.dart';

class SearchDialog extends StatefulWidget {
  final bool isGuest;
  const SearchDialog({super.key, this.isGuest = false});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  bool _isBuy = true;
  bool _aiAnalyzer = true;
  final TextEditingController _cityController = TextEditingController(text: 'Karachi');
  final TextEditingController _locationController = TextEditingController();
  
  String _selectedBusinessType = 'Sports & Fitness';
  String _selectedMinPrice = 'Min';
  String _selectedMaxPrice = 'Max';
  bool _usePriceRange = false;

  final List<String> _businessTypes = [
    'Sports & Fitness',
    'Retail & Shopping',
    'Travel & Lodging',
    'Transportation & Logistics'
  ];

  final List<String> _priceRanges = ['Min', '10k', '20k', '50k', '100k', '200k', '500k', 'Max'];

  @override
  void initState() {
    super.initState();
    if (widget.isGuest) {
      _aiAnalyzer = false;
    }
    _loadSavedSearchSettings();
  }

  Future<void> _loadSavedSearchSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _isBuy = prefs.getBool('search_isBuy') ?? true;
        _cityController.text = prefs.getString('search_city') ?? 'Karachi';
        _locationController.text = prefs.getString('search_location') ?? '';
        _selectedBusinessType = prefs.getString('search_businessType') ?? 'Sports & Fitness';
        _selectedMinPrice = prefs.getString('search_minPrice') ?? 'Min';
        _selectedMaxPrice = prefs.getString('search_maxPrice') ?? 'Max';
        _usePriceRange = prefs.getBool('search_usePriceRange') ?? false;
      });
    } catch (e) {
      debugPrint('Error loading search settings: $e');
    }
  }

  Future<void> _saveSearchSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('search_isBuy', _isBuy);
      await prefs.setString('search_city', _cityController.text);
      await prefs.setString('search_location', _locationController.text);
      await prefs.setString('search_businessType', _selectedBusinessType);
      await prefs.setString('search_minPrice', _selectedMinPrice);
      await prefs.setString('search_maxPrice', _selectedMaxPrice);
      await prefs.setBool('search_usePriceRange', _usePriceRange);
    } catch (e) {
      debugPrint('Error saving search settings: $e');
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 500;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(4), // Padding for the gradient border
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: const LinearGradient(
              colors: [Colors.red, Colors.blue],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 10,
                offset: const Offset(-10, 10),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 32, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
            ),
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LocaLogo(scale: 0.8),
                  const SizedBox(height: 24),
                  // Buy / Rent Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildToggleButton('Site Analysis', _isBuy),
                      const SizedBox(width: 16),
                      _buildToggleButton('Rent', !_isBuy),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // City and Location
                  if (isMobile) ...[
                    _buildInputField('Enter City', 'CityName', _cityController),
                    const SizedBox(height: 16),
                    _buildInputField('Location', 'Enter Location', _locationController),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildInputField('Enter City', 'CityName', _cityController),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _buildInputField('Location', 'Enter Location', _locationController),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Business and Price
                  if (isMobile) ...[
                    _buildDropdownField('Business Type', 'Select Business'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _usePriceRange,
                          activeColor: Colors.red.shade400,
                          onChanged: (val) {
                            setState(() {
                              _usePriceRange = val ?? false;
                            });
                          },
                        ),
                        Text(
                          'Filter by Price Range',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildPriceField('Price Range', true, enabled: _usePriceRange)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(Icons.arrow_forward_outlined, color: Colors.black54, size: 16),
                        ),
                        Expanded(child: _buildPriceField('', false, enabled: _usePriceRange)),
                      ],
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 32), // Align with Price Range fields which are pushed down by the checkbox row
                              _buildDropdownField('Business Type', 'Select Business'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _usePriceRange,
                                      activeColor: Colors.red.shade400,
                                      onChanged: (val) {
                                        setState(() {
                                          _usePriceRange = val ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Filter by Price Range',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _buildPriceField('Price Range', true, enabled: _usePriceRange)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Icon(Icons.arrow_forward_outlined, color: Colors.black54, size: 16),
                                  ),
                                  Expanded(child: _buildPriceField('', false, enabled: _usePriceRange)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  // AI Analyzer and Search Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'AI',
                        style: GoogleFonts.inter(color: Colors.red.shade400, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Analyzer',
                        style: GoogleFonts.inter(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _aiAnalyzer,
                        onChanged: (val) {
                          if (widget.isGuest) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please login or create an account to use the AI Analyzer.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          setState(() => _aiAnalyzer = val);
                        },
                        activeTrackColor: Colors.purple.shade400,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        _saveSearchSettings();
                        Navigator.pop(context, {
                          'city': _cityController.text,
                          'location': _locationController.text,
                          'businessType': _selectedBusinessType,
                          'minPrice': _selectedMinPrice,
                          'maxPrice': _selectedMaxPrice,
                          'usePriceRange': _usePriceRange,
                          'isBuy': _isBuy,
                          'aiAnalyzer': _aiAnalyzer,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Search',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isBuy = text == 'Site Analysis';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade400 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.blue.shade400 : Colors.grey.shade400),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBusinessType,
              isExpanded: true,
              isDense: true,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
              items: _businessTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedBusinessType = newValue!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, String hint, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField(String label, bool isMin, {bool enabled = true}) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: enabled ? Colors.red.shade400 : Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty) Text(label, style: GoogleFonts.inter(fontSize: 10, color: enabled ? Colors.grey.shade500 : Colors.grey.shade400)),
            if (label.isEmpty) const SizedBox(height: 12),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: isMin ? _selectedMinPrice : _selectedMaxPrice,
                isExpanded: true,
                isDense: true,
                style: GoogleFonts.inter(fontSize: 14, color: enabled ? Colors.black87 : Colors.grey),
                items: _priceRanges.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: enabled ? (newValue) {
                  setState(() {
                    if (isMin) {
                      _selectedMinPrice = newValue!;
                    } else {
                      _selectedMaxPrice = newValue!;
                    }
                  });
                } : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
