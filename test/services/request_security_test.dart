import 'package:pt_mate/services/storage/storage_service.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_mate/models/app_models.dart';
import 'package:pt_mate/services/api/web_adapter.dart';
import 'package:pt_mate/services/image_http_client.dart';
import 'package:pt_mate/services/network/cookie_cloud_service.dart';
import 'package:pt_mate/services/network/request_security.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart' as crypto;
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:pt_mate/services/downloader/torrent_file_downloader_mixin.dart';

class _CaptureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final String body;
  _CaptureAdapter(this.body);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _WebDavRedirectAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length == 1) {
      return ResponseBody.fromString(
        '',
        401,
        headers: {
          'www-authenticate': ['Basic realm="test"'],
        },
      );
    }
    return ResponseBody.fromString(
      '',
      302,
      headers: {
        'location': ['https://other.example/'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Proxy extends HttpOverrides {
  final int port;
  _Proxy(this.port);
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..findProxy = (_) => 'PROXY 127.0.0.1:$port';
}

class _Downloader with TorrentFileDownloaderMixin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('credentials require exact origin and safe transport', () {
    final origin = Uri.parse('https://site.example:443');
    expect(
      RequestSecurity.sameOrigin(Uri.parse('https://site.example/a'), origin),
      true,
    );
    for (final value in [
      'https://cdn.site.example',
      'https://other.example',
      'http://site.example',
      'https://site.example:444',
      'https://user@site.example',
    ]) {
      expect(RequestSecurity.sameOrigin(Uri.parse(value), origin), false);
    }
    expect(
      RequestSecurity.safeTransport(Uri.parse('http://192.168.1.2')),
      true,
    );
    expect(
      RequestSecurity.safeTransport(Uri.parse('http://public.example')),
      false,
    );
  });

  test(
    'Cookie Dio rejects external URLs before network and disables redirects',
    () async {
      final dio = WebAdapterCore.createCookieDio(
        const SiteConfig(
          id: 'test',
          name: 'test',
          baseUrl: 'https://site.example/',
          cookie: 'session=SYNTHETIC',
          siteType: SiteType.web,
        ),
      );
      final adapter = _CaptureAdapter('<html/>');
      dio.httpClientAdapter = adapter;
      await expectLater(
        dio.get('https://other.example/details'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, isEmpty);
      await dio.get('/details');
      expect(adapter.requests.single.headers['Cookie'], 'session=SYNTHETIC');
      expect(adapter.requests.single.followRedirects, false);
      dio.close();
    },
  );

  test(
    'image requests do not leak cookies between co.uk or different ports',
    () async {
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = <String?>[];
      proxy.listen((request) async {
        received.add(request.headers.value('Cookie'));
        request.response.add([1, 2, 3]);
        await request.response.close();
      });
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          await ImageHttpClient.instance.fetchImage(
            'http://images.other.co.uk/picture',
            siteBaseUrl: 'http://accounts.victim.co.uk',
            siteCookie: 'session=SYNTHETIC',
          );
          await ImageHttpClient.instance.fetchImage(
            'http://127.0.0.1:2000/picture',
            siteBaseUrl: 'http://127.0.0.1:1000',
            siteCookie: 'session=SYNTHETIC',
          );
          await ImageHttpClient.instance.fetchImage(
            'http://127.0.0.1:1000/picture',
            siteBaseUrl: 'http://127.0.0.1:1000',
            siteCookie: 'session=SYNTHETIC',
          );
        }, _Proxy(proxy.port));
        expect(received, [null, null, 'session=SYNTHETIC']);
      } finally {
        await proxy.close(force: true);
        ImageHttpClient.instance.clearCache();
      }
    },
  );

  test('WebDAV internal redirects cannot forward Basic credentials outside its origin', () async {
    const url = 'https://webdav.example';
    final client = webdav.newClient(
      url,
      user: 'synthetic',
      password: 'synthetic',
    );
    final adapter = _WebDavRedirectAdapter();
    client.c.httpClientAdapter = adapter;
    RequestSecurity.guard(client.c, url);
    try {
      await expectLater(client.readDir('/'), throwsA(isA<DioException>()));
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.last.headers['authorization'],
        startsWith('Basic '),
      );
      expect(
        adapter.requests.every((r) => r.uri.host == 'webdav.example'),
        true,
      );
    } finally {
      client.c.close(force: true);
    }
  });

  test(
    'torrent relay never sends downloader credentials to a PT site',
    () async {
      final adapter = _CaptureAdapter('torrent');
      final dio = Dio(
        BaseOptions(headers: {'Authorization': 'DOWNLOADER_SECRET'}),
      )..httpClientAdapter = adapter;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['x-api-key'] = 'DOWNLOADER_SECRET';
            handler.next(options);
          },
        ),
      );
      await _Downloader().downloadTorrentFileCommon(
        dio,
        'https://site.example/file',
        siteConfig: const SiteConfig(
          id: 'test',
          name: 'test',
          baseUrl: 'https://site.example',
          cookie: 'session=SYNTHETIC',
          siteType: SiteType.web,
        ),
      );
      expect(adapter.requests.single.headers['Cookie'], 'session=SYNTHETIC');
      expect(adapter.requests.single.headers['Authorization'], isNull);
      expect(adapter.requests.single.headers['x-api-key'], isNull);
      expect(adapter.requests.single.followRedirects, false);
      dio.close();
    },
  );

  test(
    'Cookie Cloud downloads only ciphertext and never sends the password',
    () async {
      const uuid = 'test-uuid';
      const password = 'synthetic-password';
      final seed = crypto.md5
          .convert(utf8.encode('$uuid-$password'))
          .toString()
          .substring(0, 16);
      final key = crypto.md5.convert(utf8.encode(seed)).bytes;
      final cipher = encrypt.Encrypter(
        encrypt.AES(
          encrypt.Key(Uint8List.fromList(key)),
          mode: encrypt.AESMode.cbc,
          padding: 'PKCS7',
        ),
      );
      final encrypted = cipher
          .encrypt(
            '{"cookie_data":{"site.example":"sid=test"}}',
            iv: encrypt.IV(Uint8List(16)),
          )
          .base64;
      final adapter = _CaptureAdapter(jsonEncode({'encrypted': encrypted}));
      final dio = Dio()..httpClientAdapter = adapter;
      final service = CookieCloudService(dio: dio);
      final data = await service.fetchRemoteData(
        const CookieCloudConfig(
          url: 'https://cloud.example',
          uuid: uuid,
          password: password,
        ),
      );
      expect(data.cookiesByHost['site.example'], 'sid=test');
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.data, isNull);
      expect(request.queryParameters, isEmpty);
      expect(request.followRedirects, false);
      expect(request.uri.toString(), 'https://cloud.example/get/test-uuid');
      expect(jsonEncode(request.headers), isNot(contains(password)));
    },
  );
}
