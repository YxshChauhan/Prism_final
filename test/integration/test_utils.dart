import 'dart:io';
import 'dart:convert' as convert;
import 'package:crypto/crypto.dart' show sha256;

class IntegrationCoordination {
  final String coordinationFilePath;

  IntegrationCoordination(this.coordinationFilePath);

  Future<void> writeToken(String role, String token) async {
    final File file = File(coordinationFilePath);
    Map<String, dynamic> data = {};
    if (await file.exists()) {
      try {
        data = convert.jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {}
    }
    data[role] = token;
    await file.writeAsString(convert.jsonEncode(data), flush: true);
  }

  Future<String?> readToken(String role) async {
    try {
      final File file = File(coordinationFilePath);
      if (!await file.exists()) return null;
      final Map<String, dynamic> data = convert.jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data[role] as String?;
    } catch (_) {
      return null;
    }
  }
}

Future<String> computeFileSha256(String filePath) async {
  final File file = File(filePath);
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString();
}


