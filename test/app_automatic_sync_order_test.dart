import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_mate/app.dart';
import 'package:pt_mate/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final storage = StorageService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage.resetForTest();
    storage.overridePlatformForTest(TargetPlatform.iOS);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
    await storage.initializeSecureStorage();
  });

  tearDown(() async {
    await storage.waitForPendingSecureStorageCleanup();
    storage.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test(
    'startup never restores a remote backup over local configuration',
    () async {
      final state = AppState();
      var restores = 0;
      var cookieSyncs = 0;
      state.overrideAutomaticSyncChecksForTest(
        webDav: () async => restores++,
        cookieCloud: () async => cookieSyncs++,
      );
      await state.runAutomaticSyncSequenceForTest();
      expect(restores, 0);
      expect(cookieSyncs, 1);
      state.dispose();
    },
  );
}
