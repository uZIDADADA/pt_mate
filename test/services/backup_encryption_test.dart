import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pt_mate/services/backup_encryption.dart';

void main() {
  test('encrypted backups round trip without exposing credentials', () async {
    const plaintext = '{"cookie":"SYNTHETIC_SECRET","name":"中文配置"}';
    const password = 'a-long-synthetic-backup-password';
    final first = await BackupEncryption.encrypt(plaintext, password);
    final second = await BackupEncryption.encrypt(plaintext, password);
    expect(first, isNot(contains('SYNTHETIC_SECRET')));
    expect(first, isNot(second));
    expect(await BackupEncryption.decrypt(first, password), plaintext);
    await expectLater(
      BackupEncryption.decrypt(first, 'wrong-password'),
      throwsA(isA<FormatException>()),
    );
    final tampered = jsonDecode(first) as Map<String, dynamic>;
    final bytes = base64Decode(tampered['ciphertext'] as String);
    bytes[0] ^= 1;
    tampered['ciphertext'] = base64Encode(bytes);
    await expectLater(
      BackupEncryption.decrypt(jsonEncode(tampered), password),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'weak passwords and attacker-controlled KDF parameters are rejected',
    () async {
      await expectLater(
        BackupEncryption.encrypt('{}', 'short'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        BackupEncryption.decrypt(
          jsonEncode({
            'format': BackupEncryption.format,
            'version': 1,
            'iterations': 2147483647,
          }),
          'password',
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
