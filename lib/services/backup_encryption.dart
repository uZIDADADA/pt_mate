import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

class BackupEncryption {
  static const format = 'pt-mate-encrypted-backup';
  static const iterations = 600000;
  static const maxBytes = 32 * 1024 * 1024;

  static bool isEncrypted(Map<String, dynamic> data) =>
      data['format'] == format;

  static Future<String> encrypt(String content, String password) async {
    if (password.runes.length < 12) {
      throw const FormatException('备份密码至少需要 12 个字符');
    }
    return compute(_encrypt, [content, password]);
  }

  static Future<String> decrypt(String content, String password) =>
      compute(_decrypt, [content, password]);

  static Uint8List _key(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static String _encrypt(List<String> input) {
    if (utf8.encode(input[0]).length > maxBytes) {
      throw const FormatException('备份文件过大');
    }
    final random = Random.secure();
    Uint8List bytes(int count) =>
        Uint8List.fromList(List.generate(count, (_) => random.nextInt(256)));
    final salt = bytes(16);
    final nonce = bytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(_key(input[1], salt)),
          128,
          nonce,
          Uint8List.fromList(utf8.encode(format)),
        ),
      );
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(input[0])));
    return jsonEncode({
      'format': format,
      'version': 1,
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(encrypted),
    });
  }

  static String _decrypt(List<String> input) {
    if (input[0].length > maxBytes * 2) {
      throw const FormatException('备份文件过大');
    }
    final data = jsonDecode(input[0]) as Map<String, dynamic>;
    if (!isEncrypted(data) ||
        data['version'] != 1 ||
        data['cipher'] != 'AES-256-GCM' ||
        data['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        data['iterations'] != iterations) {
      throw const FormatException('不支持的加密备份格式');
    }
    final salt = base64Decode(data['salt'] as String);
    final nonce = base64Decode(data['nonce'] as String);
    final ciphertext = base64Decode(data['ciphertext'] as String);
    if (salt.length != 16 ||
        nonce.length != 12 ||
        ciphertext.length < 16 ||
        ciphertext.length > maxBytes + 16) {
      throw const FormatException('加密备份格式无效');
    }
    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(_key(input[1], salt)),
            128,
            nonce,
            Uint8List.fromList(utf8.encode(format)),
          ),
        );
      return utf8.decode(cipher.process(ciphertext));
    } on InvalidCipherTextException {
      throw const FormatException('备份密码错误或文件已被篡改');
    }
  }
}
