import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'sos_message.dart';

/// Talks to Firebase Realtime Database over plain HTTPS (no Firebase SDK needed).
class CloudService {
  bool get configured =>
      firebaseDatabaseUrl.startsWith('https://') && !firebaseDatabaseUrl.contains('YOUR-');

  String get _base => firebaseDatabaseUrl.endsWith('/')
      ? firebaseDatabaseUrl.substring(0, firebaseDatabaseUrl.length - 1)
      : firebaseDatabaseUrl;

  /// Returns true if the message reached the rescue dashboard's database.
  /// PUT (not POST) so two online phones uploading the same SOS don't create duplicates.
  Future<bool> upload(SosMessage m, {required String uploadedBy}) async {
    try {
      final body = {
        ...m.toJson(),
        'uploadedBy': uploadedBy,
        'uploadedAt': {'.sv': 'timestamp'},
      };
      final res = await http
          .put(Uri.parse('$_base/sos/${m.id}.json'), body: jsonEncode(body))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Cheap check for whether this phone can reach the internet right now.
  Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/.json?shallow=true'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
