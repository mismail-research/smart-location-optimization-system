import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/history_service.dart';

class HistoryView extends StatefulWidget {
  final void Function(HistoryItem)? onView;
  const HistoryView({super.key, this.onView});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};

  void _toggleSelection(HistoryItem item) {
    setState(() {
      if (_selectedItems.contains(item.title)) {
        _selectedItems.remove(item.title);
      } else {
        _selectedItems.add(item.title);
      }
    });
  }

  void _showDeleteOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Options', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Do you want to delete all history, or select specific items to delete?', style: GoogleFonts.inter()),
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
      HistoryService.clearHistory();
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }

  void _handleBulkDelete() {
    setState(() {
      HistoryService.deleteHistoryItems(_selectedItems);
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    'History',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your recently viewed locations and analyses',
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
                  tooltip: 'Delete history',
                  onPressed: _showDeleteOptions,
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Search Bar
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search history...',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Timeline List
          Expanded(
            child: ValueListenableBuilder<List<HistoryItem>>(
              valueListenable: HistoryService.historyNotifier,
              builder: (context, history, _) {
                if (history.isEmpty) {
                  return Center(
                    child: Text(
                      'No history yet. Start exploring the map!',
                      style: GoogleFonts.inter(color: Colors.grey.shade500),
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      ...history.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return _buildHistoryItem(
                          context: context,
                          item: item,
                          isLast: index == history.length - 1,
                        );
                      }).toList(),
                      const SizedBox(height: 24),
                      // Load More Button
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Loading more history...')),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Load More',
                          style: GoogleFonts.inter(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required BuildContext context,
    required HistoryItem item,
    bool isLast = false,
  }) {
    Color scoreColor = item.isWarning ? Colors.amber.shade600 : Colors.green.shade600;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.location_on, color: Colors.blue.shade400, size: 18),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content Card
          Expanded(
            child: GestureDetector(
              onTap: _isSelectionMode 
                ? () => _toggleSelection(item)
                : () {
                    if (widget.onView != null) {
                      widget.onView!(item);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Viewing ${item.title} on map...')),
                      );
                    }
                  },
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSelectionMode && _selectedItems.contains(item.title) 
                      ? Colors.red.shade300 
                      : Colors.grey.shade200,
                    width: _isSelectionMode && _selectedItems.contains(item.title) ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Checkbox(
                          value: _selectedItems.contains(item.title),
                          onChanged: (_) => _toggleSelection(item),
                          activeColor: Colors.red.shade600,
                        ),
                      ),
                    Expanded(
                      child: isMobile 
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextContent(item.title, item.icon, item.type, item.time),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildScore(item.isPositive, scoreColor, item.score),
                                  _buildViewButton(context, item),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _buildTextContent(item.title, item.icon, item.type, item.time)),
                              const SizedBox(width: 16),
                              _buildScore(item.isPositive, scoreColor, item.score),
                              const SizedBox(width: 24),
                              _buildViewButton(context, item),
                            ],
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(String title, IconData icon, String type, String time) {
    return Column(
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
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  type,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScore(bool isPositive, Color scoreColor, int score) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: scoreColor,
          ),
        ),
      ],
    );
  }

  Widget _buildViewButton(BuildContext context, HistoryItem item) {
    return TextButton.icon(
      onPressed: _isSelectionMode ? null : () {
        if (widget.onView != null) {
          widget.onView!(item);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Viewing ${item.title} on map...')),
          );
        }
      },
      icon: const Icon(Icons.map_outlined, size: 16),
      label: Text('View', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue.shade700,
        backgroundColor: Colors.blue.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
