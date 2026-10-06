import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForkRelease {
  static const repository = 'uZIDADADA/pt_mate';
  static const applicationId = 'com.github.uzidadada.ptmate';
  final int buildNumber;
  final String version;
  final String apkUrl;
  final String checksum;
  final int size;

  const ForkRelease({
    required this.buildNumber,
    required this.version,
    required this.apkUrl,
    required this.checksum,
    required this.size,
  });

  factory ForkRelease.fromJson(Map<String, dynamic> json) {
    final build = json['buildNumber'];
    final size = json['size'];
    final version = json['version'];
    final checksum = json['sha256'];
    if (json['repository'] != repository ||
        json['channel'] != 'dev' ||
        json['applicationId'] != applicationId ||
        build is! int ||
        build <= 0 ||
        build > 2100000000 ||
        size is! int ||
        size <= 0 ||
        size > 128 * 1024 * 1024 ||
        version is! String ||
        version.length > 80 ||
        checksum is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum) ||
        json['apkUrl'] !=
            'https://github.com/$repository/releases/download/dev-$build/pt-mate-dev.apk') {
      throw const FormatException('更新信息无效或不属于当前仓库');
    }
    return ForkRelease(
      buildNumber: build,
      version: version,
      apkUrl: json['apkUrl'] as String,
      checksum: checksum,
      size: size,
    );
  }
}

class ForkUpdateService {
  ForkUpdateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'User-Agent': 'PTMate'},
              followRedirects: false,
            ),
          );

  static final instance = ForkUpdateService();
  static const manifestUrl =
      'https://github.com/${ForkRelease.repository}/releases/download/dev-latest/update.json';
  static const _channel = MethodChannel('pt_mate/fork_update');
  final Dio _dio;
  Future<ForkRelease?>? _pending;
  bool _downloading = false;

  Future<ForkRelease?> check({bool force = false}) async {
    if (_pending != null) return _pending;
    final future = _check(force);
    _pending = future;
    try {
      return await future;
    } finally {
      _pending = null;
    }
  }

  Future<ForkRelease?> _check(bool force) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final last = prefs.getInt('fork_update_last_check') ?? 0;
    if (!force &&
        now.millisecondsSinceEpoch - last <
            const Duration(hours: 6).inMilliseconds) {
      return null;
    }
    final response = await _get(manifestUrl);
    final bytes = <int>[];
    await for (final chunk in response.data!.stream) {
      bytes.addAll(chunk);
      if (bytes.length > 64 * 1024) throw const FormatException('更新信息过大');
    }
    final release = ForkRelease.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
    final installed = await PackageInfo.fromPlatform();
    if (installed.packageName != ForkRelease.applicationId) return null;
    await prefs.setInt('fork_update_last_check', now.millisecondsSinceEpoch);
    return release.buildNumber > (int.tryParse(installed.buildNumber) ?? 0)
        ? release
        : null;
  }

  static bool trustedUrl(Uri uri) {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.port != 443) {
      return false;
    }
    if (uri.host == 'github.com') {
      return uri.path.startsWith(
        '/${ForkRelease.repository}/releases/download/',
      );
    }
    return const {
      'release-assets.githubusercontent.com',
      'objects.githubusercontent.com',
    }.contains(uri.host);
  }

  Future<Response<ResponseBody>> _get(
    String url, {
    CancelToken? cancelToken,
  }) async {
    var uri = Uri.parse(url);
    for (var redirects = 0; redirects <= 5; redirects++) {
      if (!trustedUrl(uri)) throw const FormatException('已阻止外部更新地址');
      final response = await _dio.get<ResponseBody>(
        uri.toString(),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          headers: {'Cookie': null, 'Authorization': null, 'x-api-key': null},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      if (response.statusCode == 200) return response;
      await response.data?.stream.drain<void>();
      final location = response.headers.value('location');
      if (location == null) break;
      uri = uri.resolve(location);
    }
    throw const FormatException('更新下载重定向无效');
  }

  Future<bool> downloadAndInstall(
    ForkRelease release, {
    required void Function(double value) onProgress,
    CancelToken? cancelToken,
  }) async {
    if (_downloading) throw StateError('已有更新正在下载');
    _downloading = true;
    try {
      return await _downloadAndInstall(
        release,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } finally {
      _downloading = false;
    }
  }

  Future<bool> _downloadAndInstall(
    ForkRelease release, {
    required void Function(double value) onProgress,
    CancelToken? cancelToken,
  }) async {
    // Revalidate even if a caller constructs the model directly.
    ForkRelease.fromJson({
      'repository': ForkRelease.repository,
      'channel': 'dev',
      'applicationId': ForkRelease.applicationId,
      'buildNumber': release.buildNumber,
      'version': release.version,
      'apkUrl': release.apkUrl,
      'sha256': release.checksum,
      'size': release.size,
    });
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/pt_mate_updates',
    );
    await directory.create(recursive: true);
    final file = File('${directory.path}/update.apk');
    final partial = File('${directory.path}/update.apk.part');
    var completed = false;
    try {
      final response = await _get(release.apkUrl, cancelToken: cancelToken);
      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.data!.stream) {
          if (cancelToken?.isCancelled ?? false) {
            throw cancelToken!.cancelError!;
          }
          received += chunk.length;
          if (received > release.size) throw const FormatException('更新包大小不符');
          sink.add(chunk);
          onProgress(received / release.size);
        }
      } finally {
        await sink.close();
      }
      if (received != release.size ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              release.checksum) {
        throw const FormatException('更新包校验失败，已阻止安装');
      }
      if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
      if (await file.exists()) await file.delete();
      await partial.rename(file.path);
      final launched =
          await _channel.invokeMethod<bool>('install', {
            'path': file.path,
            'sha256': release.checksum,
            'buildNumber': release.buildNumber,
          }) ??
          false;
      completed = true;
      return launched;
    } finally {
      if (await partial.exists()) await partial.delete();
      if (!completed && await file.exists()) await file.delete();
    }
  }
}
