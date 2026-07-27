import 'package:flutter/material.dart';
import 'dart:convert';
import 'user_data_sync_service.dart';

class HistoryItem {
  final String title;
  final String type;
  final String time;
  final int score;
  final bool isPositive;
  final IconData icon;
  final bool isWarning;
  final double? lat;
  final double? lon;
  final Map<String, dynamic>? analysisData;

  HistoryItem({
    required this.title,
    required this.type,
    required this.time,
    required this.score,
    required this.isPositive,
    required this.icon,
    this.isWarning = false,
    this.lat,
    this.lon,
    this.analysisData,
  });
}

class HistoryService {
  static final List<HistoryItem> _history = [];

  static final ValueNotifier<List<HistoryItem>> historyNotifier = ValueNotifier<List<HistoryItem>>(_history);

  static void addToHistory(Map<String, dynamic> locationData, {Map<String, dynamic>? analysisData}) {
    final rawLat = locationData['lat'] ?? locationData['latitude'] ?? analysisData?['lat'] ?? analysisData?['latitude'];
    final rawLon = locationData['lon'] ?? locationData['lng'] ?? locationData['longitude'] ?? analysisData?['lon'] ?? analysisData?['longitude'] ?? analysisData?['lng'];

    final newItem = HistoryItem(
      title: locationData['title'] ?? 'Unknown Location',
      type: locationData['type'] ?? 'Location View',
      time: 'Just now',
      score: locationData['score'] ?? 0,
      isPositive: (locationData['score'] ?? 0) >= 50,
      isWarning: (locationData['score'] ?? 0) < 70,
      icon: Icons.visibility_outlined,
      lat: rawLat != null ? (rawLat as num).toDouble() : null,
      lon: rawLon != null ? (rawLon as num).toDouble() : null,
      analysisData: analysisData,
    );

    // Check if already in history (by title for simplicity)
    if (_history.any((item) => item.title == newItem.title)) {
      _history.removeWhere((item) => item.title == newItem.title);
    }
    
    _history.insert(0, newItem);
    historyNotifier.value = List.from(_history);
    UserDataSyncService.saveUserData();
  }

  static List<Map<String, dynamic>> getHistoryRaw() {
    return _history.map((item) => {
      'title': item.title,
      'type': item.type,
      'time': item.time,
      'score': item.score,
      'isPositive': item.isPositive,
      'icon_code': item.icon.codePoint,
      'isWarning': item.isWarning,
      'lat': item.lat,
      'lon': item.lon,
      'analysisData': item.analysisData,
    }).toList();
  }

  static void loadHistoryRaw(dynamic data, {bool merge = false}) {
    dynamic parsedData = data;
    if (data is String) {
      try {
        parsedData = jsonDecode(data);
      } catch (e) {
        debugPrint('HistoryService: Error decoding history JSON string: $e');
      }
    }

    if (parsedData is List) {
      final List<HistoryItem> incoming = [];
      for (final item in parsedData) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          incoming.add(HistoryItem(
            title: map['title'] ?? 'Unknown Location',
            type: map['type'] ?? 'Location View',
            time: map['time'] ?? '',
            score: map['score'] ?? 0,
            isPositive: map['isPositive'] ?? true,
            icon: IconData(map['icon_code'] ?? 58341, fontFamily: 'MaterialIcons'),
            isWarning: map['isWarning'] ?? false,
            lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
            lon: map['lon'] != null ? (map['lon'] as num).toDouble() : null,
            analysisData: map['analysisData'],
          ));
        }
      }

      if (merge) {
        for (final item in incoming) {
          if (!_history.any((h) => h.title == item.title)) {
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

  static void deleteHistoryItems(Set<String> titles) {
    _history.removeWhere((item) => titles.contains(item.title));
    historyNotifier.value = List.from(_history);
    UserDataSyncService.saveUserData();
  }

  static void clearHistory() {
    _history.clear();
    historyNotifier.value = [];
    UserDataSyncService.saveUserData();
  }

  static void clearData() {
    _history.clear();
    historyNotifier.value = [];
  }
}
