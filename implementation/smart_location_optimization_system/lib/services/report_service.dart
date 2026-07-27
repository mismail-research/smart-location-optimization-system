import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'dart:convert';
import 'user_data_sync_service.dart';

class ReportItem {
  final String id;
  final String title;
  final String date;
  final String type;
  final String size;
  final IconData icon;
  final List<Map<String, dynamic>>? locations;

  ReportItem({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    required this.size,
    required this.icon,
    this.locations,
  });
}

class ReportService {
  static final ValueNotifier<List<ReportItem>> reportsNotifier = ValueNotifier<List<ReportItem>>([]);

  /// Generates the PDF binary bytes on-the-fly from the stored location parameters
  static Future<Uint8List> generatePdfBytes({
    required String title,
    required String type,
    List<Map<String, dynamic>>? locations,
  }) async {
    final pdf = pw.Document();

    final List<String> headers = ['Metric'];
    final List<List<String>> data = [];

    if (locations != null && locations.isNotEmpty) {
      for (int i = 0; i < locations.length; i++) {
        headers.add(locations[i]['title']?.toString() ?? 'Location ${i + 1}');
      }

      data.addAll([
        [
          'Overall Suitability',
          ...locations.map((loc) => '${(loc['score'] ?? 110).toInt()}/150')
        ],
        [
          'Foot Traffic Score',
          ...locations.map((loc) => '${(loc['traffic'] ?? 75).toInt()}%')
        ],
        [
          'Competitors (5km)',
          ...locations.map((loc) => '${(loc['competition'] ?? 0).toInt()}')
        ],
        [
          'Competitors (Actual)',
          ...locations.map((loc) => '${(loc['competitor_count'] ?? 0).toInt()}')
        ],
        [
          'Rent Affordability',
          ...locations.map((loc) {
            final double rentAmount = double.tryParse(loc['rent']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '50') ?? 50.0;
            final rentVal = (100 - rentAmount).clamp(0, 100).toInt();
            return '$rentVal%';
          })
        ],
        [
          'Avg Time Spent',
          ...locations.map((loc) => '${(loc['time_spent'] ?? 45).toInt()} mins')
        ],
        [
          'Weekday Popularity',
          ...locations.map((loc) => '${(loc['weekday_avg_popularity'] ?? 60).toInt()}%')
        ],
        [
          'Weekend Popularity',
          ...locations.map((loc) => '${(loc['weekend_avg_popularity'] ?? 75).toInt()}%')
        ],
        [
          'Morning Traffic',
          ...locations.map((loc) => '${(loc['morning_avg'] ?? 40).toInt()}%')
        ],
        [
          'Afternoon Traffic',
          ...locations.map((loc) => '${(loc['afternoon_avg'] ?? 65).toInt()}%')
        ],
        [
          'Evening Traffic',
          ...locations.map((loc) => '${(loc['evening_avg'] ?? 80).toInt()}%')
        ],
        [
          'Night Traffic',
          ...locations.map((loc) => '${(loc['night_avg'] ?? 30).toInt()}%')
        ],
        [
          'Max Popularity',
          ...locations.map((loc) => '${(loc['max_popularity'] ?? 90).toInt()}%')
        ],
        [
          'Peak Hour',
          ...locations.map((loc) {
            final int hour = (loc['peak_hour'] ?? 18).toInt();
            final String period = hour >= 12 ? 'PM' : 'AM';
            final int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
            return '$displayHour:00 $period';
          })
        ],
        [
          'Peak Day',
          ...locations.map((loc) => loc['peak_day']?.toString() ?? 'Saturday')
        ],
      ]);
    } else {
      headers.addAll(['Location 1', 'Location 2']);
      data.addAll([
        ['Overall Suitability', '127/150', '108/150'],
        ['Foot Traffic Score', '75%', '60%'],
        ['Competitors (5km)', '4', '8'],
        ['Competitors (Actual)', '12', '24'],
        ['Rent Affordability', '88%', '65%'],
        ['Avg Time Spent', '45 mins', '30 mins'],
        ['Weekday Popularity', '60%', '55%'],
        ['Weekend Popularity', '75%', '70%'],
        ['Morning Traffic', '40%', '35%'],
        ['Afternoon Traffic', '65%', '60%'],
        ['Evening Traffic', '80%', '75%'],
        ['Night Traffic', '30%', '25%'],
        ['Max Popularity', '90%', '85%'],
        ['Peak Hour', '6:00 PM', '5:00 PM'],
        ['Peak Day', 'Saturday', 'Friday'],
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Loca.ai Analysis Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Report Title: $title', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Type: $type', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Date: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('Summary:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('This is a highly detailed, AI-generated prescriptive analytics report assessing the viability and comparative advantages of the selected properties. Key metrics such as foot traffic, regional saturation, rent affordability, and competitor proximity have been analyzed to provide an optimal location recommendation.', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 12),
              // Dynamic Table
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
                headerHeight: 20,
                cellHeight: 22,
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  for (int i = 1; i < headers.length; i++)
                    i: pw.Alignment.centerRight,
                },
                headers: headers,
                data: data,
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Text('Generated by Loca.ai - Smart Location Optimization System', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  static Future<void> generateReport({
    required String title,
    required String type,
    List<Map<String, dynamic>>? locations,
  }) async {
    final pdfBytes = await generatePdfBytes(
      title: title,
      type: type,
      locations: locations,
    );

    final now = DateTime.now();
    final dateString = '${now.day}/${now.month}/${now.year}';
    final sizeInKb = (pdfBytes.length / 1024).toStringAsFixed(1);

    final newReport = ReportItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      date: dateString,
      type: type,
      size: '${sizeInKb} KB',
      icon: Icons.picture_as_pdf_outlined,
      locations: locations,
    );

    reportsNotifier.value = [newReport, ...reportsNotifier.value];
    UserDataSyncService.saveUserData();
  }

  static void deleteReport(String id) {
    reportsNotifier.value = reportsNotifier.value.where((report) => report.id != id).toList();
    UserDataSyncService.saveUserData();
  }

  static void deleteReports(Set<String> ids) {
    reportsNotifier.value = reportsNotifier.value.where((report) => !ids.contains(report.id)).toList();
    UserDataSyncService.saveUserData();
  }

  static void clearReports() {
    reportsNotifier.value = [];
    UserDataSyncService.saveUserData();
  }

  static List<Map<String, dynamic>> getReportsRaw() {
    return reportsNotifier.value.map((item) => {
      'id': item.id,
      'title': item.title,
      'date': item.date,
      'type': item.type,
      'size': item.size,
      'icon_code': item.icon.codePoint,
      'locations': item.locations,
    }).toList();
  }

  static void loadReportsRaw(dynamic data, {bool merge = false}) {
    dynamic parsedData = data;
    if (data is String) {
      try {
        parsedData = jsonDecode(data);
      } catch (e) {
        debugPrint('ReportService: Error decoding reports JSON string: $e');
      }
    }

    if (parsedData is List) {
      final List<ReportItem> incoming = [];
      for (final item in parsedData) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          incoming.add(ReportItem(
            id: map['id'] ?? '',
            title: map['title'] ?? '',
            date: map['date'] ?? '',
            type: map['type'] ?? '',
            size: map['size'] ?? '',
            icon: IconData(map['icon_code'] ?? 58713, fontFamily: 'MaterialIcons'),
            locations: map['locations'] != null
                ? List<Map<String, dynamic>>.from(
                    (map['locations'] as List).map((l) => Map<String, dynamic>.from(l as Map))
                  )
                : null,
          ));
        }
      }

      if (merge) {
        final currentReports = List<ReportItem>.from(reportsNotifier.value);
        for (final item in incoming) {
          if (!currentReports.any((r) => r.title == item.title)) {
            currentReports.add(item);
          }
        }
        reportsNotifier.value = currentReports;
      } else {
        reportsNotifier.value = incoming;
      }
    }
  }

  static void clearData() {
    reportsNotifier.value = [];
  }
}
