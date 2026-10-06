import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_mate/models/app_models.dart';
import 'package:pt_mate/services/api/api_exceptions.dart';
import 'package:pt_mate/services/api/web_adapter.dart';
import 'package:pt_mate/services/site_config_service.dart';

class _FixtureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final String profile;
  final String torrents;

  _FixtureAdapter({required this.profile, required this.torrents});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      options.path == '/torrents.php' ? torrents : profile,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SiteConfigService.clearAllCache);
  tearDown(SiteConfigService.clearAllCache);

  for (final id in ['happyfappy', 'empornium']) {
    group('$id Luminance preset', () {
      test(
        'loads from the manifest with Cookie authentication and categories',
        () async {
          final templates = await SiteConfigService.loadPresetSiteTemplates();
          final template = templates.firstWhere((item) => item.id == id);
          expect(template.siteType, SiteType.web);
          expect(template.siteType.usesCookieAuthentication, isTrue);
          expect(template.siteType.supportsGazelleDownloadToken, isFalse);
          expect(template.operationIntervalMs, 1000);
          expect(template.features.supportCollection, isFalse);
          expect(template.features.supportHistory, isFalse);
          expect(template.features.supportCategories, isTrue);
          expect(template.searchCategories.first.parseParameters(), isEmpty);
          expect(
            template.searchCategories,
            hasLength(id == 'happyfappy' ? 15 : 48),
          );
          for (final category in template.searchCategories.skip(1)) {
            expect(category.parseParameters(), {
              'filter_cat[${category.id}]': '1',
            });
          }
          final mapping = await SiteConfigService.getUrlToTemplateIdMapping();
          for (final url in template.baseUrls) {
            expect(mapping[url.replaceFirst(RegExp(r'/$'), '')], id);
          }
        },
      );

      test('parses IDs, signed links, covers, promotions, dates and pagination', () async {
        final template = (await SiteConfigService.getTemplateById(
          id,
          SiteType.web,
        ))!;
        final html = await File('test/fixtures/luminance_torrents.html')
            .readAsString();
        final result = WebSearchParser.parse(
          html: html,
          searchConfig: template.infoFinder!['search'] as Map<String, dynamic>,
          baseUrl: template.primaryUrl!,
          discountMapping: template.discountMapping,
        );
        expect(result.totalPages, 42);
        expect(result.candidateItemRows, 3);
        expect(result.items, hasLength(3));
        final first = result.items.first;
        expect(first.id, '701');
        expect(first.name, 'Example Release');
        expect(first.detailUrl, '${template.primaryUrl}torrents.php?id=700');
        expect(
          first.downloadUrl,
          '${template.primaryUrl}torrents.php?action=download&id=701&authkey=fixture-auth&torrent_pass=fixture-pass',
        );
        expect(
          first.cover,
          'https://images.example.test/cover-700.jpg?a=1&b=2',
        );
        expect(first.smallDescr, 'example hd');
        expect(first.discount, DiscountType.free);
        expect(first.comments, 14);
        expect(first.sizeBytes, 1342177280);
        expect(first.seeders, 1234);
        expect(first.leechers, 5);
        expect(first.createdDate.toUtc(), DateTime.utc(2025, 4, 1, 15, 12));
        final second = result.items[1];
        expect(second.cover, isEmpty);
        expect(second.discount, DiscountType.free);
        expect(second.createdDate.toUtc(), DateTime.utc(2025, 3, 31, 9, 30));
        final third = result.items.last;
        expect(third.cover, isEmpty);
        expect(third.discount, DiscountType.normal);
        expect(third.sizeBytes, 1073741824);
      });

      test(
        'fetches profiles and sends browse/search/category/page parameters',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.linux;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final template = (await SiteConfigService.getTemplateById(
            id,
            SiteType.web,
          ))!;
          final config = template.toSiteConfig(
            cookie: 'session=fixture-cookie',
          );
          final client = _FixtureAdapter(
            profile: await File('test/fixtures/luminance_profile.html')
                .readAsString(),
            torrents: await File('test/fixtures/luminance_torrents.html')
                .readAsString(),
          );
          final dio = WebAdapterCore.createCookieDio(config)
            ..httpClientAdapter = client;
          addTearDown(() => dio.close(force: true));
          final adapter = WebAdapter(dio: dio);
          await adapter.init(config);
          final profile = await adapter.fetchMemberProfile();
          expect(profile.userId, '42');
          expect(profile.username, 'fixture-user');
          expect(profile.uploadedBytes, 2748779069440);
          expect(profile.downloadedBytes, 549755813888);
          expect(profile.shareRate, 5);
          expect(profile.bonus, 12345);
          expect(client.requests.map((request) => request.path), [
            '/',
            '/user.php?id=42',
          ]);
          final browse = await adapter.searchTorrents();
          expect(browse.items, hasLength(3));
          expect(client.requests.last.queryParameters['title'], '');
          final category = template.searchCategories[1];
          final search = await adapter.searchTorrents(
            keyword: 'example & test',
            pageNumber: 2,
            additionalParams: category.parseParameters(),
          );
          expect(search.pageNumber, 2);
          expect(search.totalPages, 42);
          expect(client.requests.last.queryParameters, {
            'action': 'advanced',
            'title': 'example & test',
            'page': '2',
            'order_by': 'time',
            'order_way': 'desc',
            'filter_cat[${category.id}]': '1',
          });
          expect(
            client.requests.every(
              (request) =>
                  request.headers['Cookie'] == 'session=fixture-cookie',
            ),
            isTrue,
          );
          final item = search.items.first;
          expect(
            await adapter.genDlToken(id: item.id, url: item.downloadUrl),
            item.downloadUrl,
          );
          // Missing signed download links must fail instead of guessing a group ID.
          await expectLater(
            adapter.genDlToken(id: item.id),
            throwsA(isA<SiteServiceException>()),
          );
          final detail = await adapter.fetchTorrentDetail(
            item.id,
            detailUrl: item.detailUrl,
          );
          expect(detail.webviewUrl, item.detailUrl);
          final fallbackDetail = await adapter.fetchTorrentDetail(item.id);
          expect(
            fallbackDetail.webviewUrl,
            '${template.primaryUrl}torrents.php?torrentid=701',
          );
        },
      );

      test('rejects a 200 login page as an expired Cookie', () async {
        final template = (await SiteConfigService.getTemplateById(
          id,
          SiteType.web,
        ))!;
        final config = template.toSiteConfig(cookie: 'session=expired');
        final dio = WebAdapterCore.createCookieDio(config)
          ..httpClientAdapter = _FixtureAdapter(
            profile:
                '<html><body><form id="loginform">Login</form></body></html>',
            torrents: '',
          );
        addTearDown(() => dio.close(force: true));
        final adapter = WebAdapter(dio: dio);
        await adapter.init(config);
        await expectLater(
          adapter.fetchMemberProfile(),
          throwsA(isA<SiteAuthenticationException>()),
        );
      });
    });
  }
}
