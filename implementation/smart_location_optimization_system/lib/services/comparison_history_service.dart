import 'package:flutter/material.dart';
import 'dart:convert';
import 'user_data_sync_service.dart';

class ComparisonHistoryItem {
  final String id;
  final String title;
  final String time;
  final List<Map<String, dynamic>> locations;

  ComparisonHistoryItem({
    required this.id,
    required this.title,
    required this.time,
    required this.locations,
  });
}

class ComparisonHistoryService {
  static final List<ComparisonHistoryItem> _history = [];
  static final ValueNotifier<List<ComparisonHistoryItem>> historyNotifier =
      ValueNotifier<List<ComparisonHistoryItem>>(_history);

  static void addComparison(List<Map<String, dynamic>> locations) {
    if (locations.isEmpty) return;
    
    // Create a beautiful default title representing the compared sites
    final titles = locations.map((loc) => loc['title'] ?? 'Unknown Site').toList();
    final String title = titles.join(' vs ');
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    // Format date and time
    final String time = "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} ${_twoDigits(now.hour)}:${_twoDigits(now.minute)}";

    final newItem = ComparisonHistoryItem(
      id: id,
      title: title,
      time: time,
      locations: locations,
    );

    // To prevent duplicate entries of the exact same comparison titles, remove old matching one
    _history.removeWhere((item) => item.title == title);

    _history.insert(0, newItem);
    historyNotifier.value = List.from(_history);
    UserDataSyncService.saveUserData();
  }

  static List<Map<String, dynamic>> getHistoryRaw() {
    return _history.map((item) => {
      'id': item.id,
      'title': item.title,
      'time': item.time,
      'locations': item.locations,
    }).toList();
  }

  static void loadHistoryRaw(dynamic data, {bool merge = false}) {
    dynamic parsedData = data;
    if (data is String) {
      try {
        parsedData = jsonDecode(data);
      } catch (e) {
        debugPrint('ComparisonHistoryService: Error decoding comparison history JSON string: $e');
      }
    }

    if (parsedData is List) {
      final List<ComparisonHistoryItem> incoming = [];
      for (final item in parsedData) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          incoming.add(ComparisonHistoryItem(
            id: map['id'] ?? '',
            title: map['title'] ?? '',
            time: map['time'] ?? '',
            locations: List<Map<String, dynamic>>.from(
              (map['locations'] as List? ?? []).map((l) => Map<String, dynamic>.from(l as Map))
            ),
          ));
        }
      }

      if (merge) {
        for (final item in incoming) {
          if (!_history.any((c) => c.title == item.title)) {
            _history.add(item);
          }
        }
      } else {
        _history.clear();
        _history.addAll(incoming);
      }
      historyNotifier.value = List.from(_history);
    }
  }

  static void clearData() {
    _history.clear();
    historyNotifier.value = [];
  }

  static String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }
}
