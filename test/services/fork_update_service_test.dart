import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pt_mate/services/fork_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> manifest(int build) => {
  'repository': ForkRelease.repository,
  'channel': 'dev',
  'applicationId': ForkRelease.applicationId,
  'buildNumber': build,
  'version': '2.29.3-dev.$build',
  'size': 100,
  'sha256': List.filled(64, 'a').join(),
  'apkUrl':
      'https://github.com/${ForkRelease.repository}/releases/download/dev-$build/pt-mate-dev.apk',
};

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Map<String, dynamic> data;
  String? redirect;
  _Adapter(this.data);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return redirect == null
        ? ResponseBody.fromString(jsonEncode(data), 200)
        : ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': [redirect!],
            },
          );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'existing-config': 'keep-me'});
    PackageInfo.setMockInitialValues(
      appName: 'PT Mate Dev',
      packageName: ForkRelease.applicationId,
      version: '2.29.3-dev.1',
      buildNumber: '200001',
      buildSignature: '',
    );
  });

  test(
    'accepts only this repository, package, channel and exact APK asset',
    () {
      expect(ForkRelease.fromJson(manifest(200002)).buildNumber, 200002);
      for (final field in [
        'repository',
        'channel',
        'applicationId',
        'apkUrl',
        'sha256',
      ]) {
        final invalid = manifest(200002)..[field] = 'attacker';
        expect(() => ForkRelease.fromJson(invalid), throwsFormatException);
      }
      expect(
        ForkUpdateService.trustedUrl(Uri.parse('https://evil.example/app.apk')),
        false,
      );
      expect(
        ForkUpdateService.trustedUrl(
          Uri.parse('https://github.com/other/repo/releases/download/x/a'),
        ),
        false,
      );
    },
  );

  test(
    'updates use public GET without identifiers; config stays untouched',
    () async {
      final adapter = _Adapter(manifest(200002));
      final service = ForkUpdateService(
        dio: Dio()..httpClientAdapter = adapter,
      );
      expect((await service.check(force: true))!.buildNumber, 200002);
      final request = adapter.requests.single;
      expect(request.uri.toString(), ForkUpdateService.manifestUrl);
      expect(request.method, 'GET');
      expect(request.data, isNull);
      expect(request.queryParameters, isEmpty);
      expect(request.headers['Cookie'], isNull);
      expect(request.headers['Authorization'], isNull);
      expect(await service.check(), isNull);
      expect(adapter.requests, hasLength(1));
      expect(
        (await SharedPreferences.getInstance()).getString('existing-config'),
        'keep-me',
      );
      adapter.data = manifest(200001);
      expect(await service.check(force: true), isNull);
    },
  );

  test('external redirects are rejected before contacting them', () async {
    final adapter = _Adapter(manifest(200002))
      ..redirect = 'https://evil.example/update.json';
    final service = ForkUpdateService(dio: Dio()..httpClientAdapter = adapter);
    await expectLater(service.check(force: true), throwsFormatException);
    expect(adapter.requests, hasLength(1));
  });
}
