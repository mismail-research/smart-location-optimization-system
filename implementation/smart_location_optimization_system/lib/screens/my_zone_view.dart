import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../services/api_service.dart';
import '../services/report_service.dart';

class MyZoneView extends StatefulWidget {
  final void Function(double lat, double lon, String title, String subtitle, Map<String, dynamic> item)? onViewOnMap;
  final int initialTabIndex;

  const MyZoneView({
    super.key,
    this.onViewOnMap,
    this.initialTabIndex = 0,
  });

  @override
  State<MyZoneView> createState() => _MyZoneViewState();
}

class _MyZoneViewState extends State<MyZoneView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late int _selectedTabIndex;
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};

  String _getItemKey(dynamic item) {
    if (item is ReportItem) return item.id;
    if (item is Map) return "${item['lat']}_${item['lon']}";
    return item.hashCode.toString();
  }

  void _toggleSelection(dynamic item) {
    final key = _getItemKey(item);
    setState(() {
      if (_selectedItems.contains(key)) {
        _selectedItems.remove(key);
      } else {
        _selectedItems.add(key);
      }
    });
  }

  void _showDeleteOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Options', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Do you want to delete all items in this section, or select specific items to delete?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isSelectionMode = true;
                _selectedItems.clear();
              });
            },
            child: Text('Choose', style: GoogleFonts.inter(color: Colors.blue)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleDeleteAll();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            child: Text('Delete All', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAll() {
    setState(() {
      if (_selectedTabIndex == 0) {
        ApiService.clearSavedLocations();
      } else if (_selectedTabIndex == 1) {
        ReportService.clearReports();
      } else if (_selectedTabIndex == 2) {
        ApiService.clearFavorites();
      }
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }

  void _handleBulkDelete() {
    setState(() {
      if (_selectedTabIndex == 0) {
        final locs = ApiService.savedLocationsNotifier.value.where((l) => _selectedItems.contains(_getItemKey(l))).toSet();
        ApiService.deleteSavedLocations(locs);
      } else if (_selectedTabIndex == 1) {
        ReportService.deleteReports(_selectedItems);
      } else if (_selectedTabIndex == 2) {
        final locs = ApiService.favoritesNotifier.value.where((l) => _selectedItems.contains(_getItemKey(l))).toSet();
        ApiService.deleteFavorites(locs);
      }
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
  }

  @override
  void didUpdateWidget(covariant MyZoneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _selectedTabIndex = widget.initialTabIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Zone',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your saved locations, reports, and favorites',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (_isSelectionMode)
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedItems.clear();
                        });
                      },
                      child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _selectedItems.isEmpty ? null : _handleBulkDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text('Delete (${_selectedItems.length})'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                    ),
                  ],
                )
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete items',
                  onPressed: _showDeleteOptions,
                ),
            ],
          ),
          const SizedBox(height: 32),
          // Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTab(0, Icons.location_on_outlined, 'Saved Locations'),
                const SizedBox(width: 16),
                _buildTab(1, Icons.description_outlined, 'Reports'),
                const SizedBox(width: 16),
                _buildTab(2, Icons.favorite_border, 'Favorites'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Content
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTabIndex == 0) {
      return ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: ApiService.savedLocationsNotifier,
        builder: (context, savedLocations, child) {
          if (savedLocations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No saved locations yet', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Analyze locations on the map and tap "Save" to build your list', 
                    style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            );
          }
          return GridView(
            padding: const EdgeInsets.only(bottom: 32),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 200,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            children: savedLocations.map((loc) => _buildLocationCard(loc)).toList(),
          );
        },
      );
    } else if (_selectedTabIndex == 1) {
      return ValueListenableBuilder<List<ReportItem>>(
        valueListenable: ReportService.reportsNotifier,
        builder: (context, reports, child) {
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No reports generated yet', style: GoogleFonts.inter(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return GestureDetector(
                onTap: _isSelectionMode ? () => _toggleSelection(report) : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isSelectionMode && _selectedItems.contains(_getItemKey(report)) 
                        ? Colors.red.shade300 
                        : Colors.grey.shade200,
                      width: _isSelectionMode && _selectedItems.contains(_getItemKey(report)) ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Checkbox(
                            value: _selectedItems.contains(_getItemKey(report)),
                            onChanged: (_) => _toggleSelection(report),
                            activeColor: Colors.red.shade600,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Icon(report.icon, color: Colors.red.shade400, size: 32),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(report.date, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                                const SizedBox(width: 16),
                                Icon(Icons.insert_drive_file_outlined, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text('${report.type} • ${report.size}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!_isSelectionMode)
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  final pdfBytes = await ReportService.generatePdfBytes(
                                    title: report.title,
                                    type: report.type,
                                    locations: report.locations,
                                  );
                                  await Printing.layoutPdf(
                                    onLayout: (format) async => pdfBytes,
                                    name: report.title,
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error viewing PDF: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              icon: const Icon(Icons.visibility_outlined, color: Colors.purple),
                              label: Text('View', style: GoogleFonts.inter(color: Colors.purple, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.purple.shade50,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  final pdfBytes = await ReportService.generatePdfBytes(
                                    title: report.title,
                                    type: report.type,
                                    locations: report.locations,
                                  );
                                  await Printing.sharePdf(
                                    bytes: pdfBytes,
                                    filename: '${report.title.replaceAll(' ', '_')}.pdf',
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              icon: const Icon(Icons.download_rounded, color: Colors.blue),
                              label: Text('Download', style: GoogleFonts.inter(color: Colors.blue, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                ReportService.deleteReport(report.id);
                              },
                              icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                              tooltip: 'Delete Report',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } else if (_selectedTabIndex == 2) {
      return ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: ApiService.favoritesNotifier,
        builder: (context, favorites, child) {
          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No favorites added yet', style: GoogleFonts.inter(color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Go to Map and tap the heart icon on any location', 
                    style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            );
          }
          return GridView(
            padding: const EdgeInsets.only(bottom: 32),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 200,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            children: favorites.map((loc) => _buildLocationCard(loc)).toList(),
          );
        },
      );
    }
    return const SizedBox();
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? Border.all(color: Colors.grey.shade300) : Border.all(color: Colors.transparent),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.black87 : Colors.grey.shade500),
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

  Widget _buildLocationCard(Map<String, dynamic> loc, {bool isWarning = false}) {
    final title = loc['title'] ?? 'Unknown';
    final subtitle = loc['subtitle'] ?? loc['address'] ?? 'No details';
    final score = loc['score'] ?? 0;
    final isPositive = loc['isPositive'] ?? true;
    final lat = loc['lat'] ?? 0.0;
    final lon = loc['lon'] ?? 0.0;
    Color scoreColor = isWarning ? Colors.amber.shade600 : Colors.green.shade600;

    return GestureDetector(
      onTap: _isSelectionMode ? () => _toggleSelection(loc) : null,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSelectionMode && _selectedItems.contains(_getItemKey(loc)) 
                ? Colors.red.shade300 
                : Colors.grey.shade200,
            width: _isSelectionMode && _selectedItems.contains(_getItemKey(loc)) ? 2 : 1,
          ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Checkbox(
                      value: _selectedItems.contains(_getItemKey(loc)),
                      onChanged: (_) => _toggleSelection(loc),
                      activeColor: Colors.red.shade600,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle.isNotEmpty && subtitle.toLowerCase() != 'no details') ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: scoreColor,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      score.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSelectionMode ? null : () {
                  if (widget.onViewOnMap != null) {
                    widget.onViewOnMap!(lat, lon, title, subtitle, loc);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Locating $title on Map (Lat: $lat, Lon: $lon)')),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: _isSelectionMode ? Colors.grey.shade300 : Colors.blue.shade300),
                ),
                child: Text(
                  'View',
                  style: GoogleFonts.inter(
                    color: _isSelectionMode ? Colors.grey.shade400 : Colors.blue.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
