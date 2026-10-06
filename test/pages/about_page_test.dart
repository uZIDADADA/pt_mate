import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pt_mate/pages/about_page.dart';
import 'package:pt_mate/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.instance.resetForTest();
    PackageInfo.setMockInitialValues(
      appName: 'PT Mate',
      packageName: 'com.github.justlookatnow.ptmate',
      version: '2.29.3',
      buildNumber: '191',
      buildSignature: '',
    );
  });

  tearDown(() => StorageService.instance.resetForTest());

  testWidgets('关于页无隐式联网，复制版本信息指向 fork', (tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    var httpClientsCreated = 0;
    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(const MaterialApp(home: AboutPage()));
        await tester.pumpAndSettle();

        expect(find.text('当前版本 v2.29.3+191'), findsOneWidget);
        expect(find.text('查看 Releases'), findsOneWidget);
        expect(find.text('检查更新'), findsOneWidget);
        expect(find.textContaining('Telegram'), findsNothing);
        expect(find.text('JustLookAtNow'), findsNothing);

        await tester.tap(find.text('复制版本信息'));
        await tester.pumpAndSettle();
        expect(
          copiedText,
          'PT Mate v2.29.3+191\nhttps://github.com/uZIDADADA/pt_mate',
        );

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
      createHttpClient: (_) {
        httpClientsCreated++;
        throw StateError('关于页不应自动创建 HTTP 客户端');
      },
    );
    expect(httpClientsCreated, 0);
    expect(tester.takeException(), isNull);
  });
}
