import 'package:dio/dio.dart';

/// Credentials belong to one origin, including its scheme and port.
class RequestSecurity {
  RequestSecurity._();

  static bool sameOrigin(Uri target, Uri origin) =>
      (target.scheme == 'https' || target.scheme == 'http') &&
      target.scheme == origin.scheme &&
      target.host.toLowerCase() == origin.host.toLowerCase() &&
      target.port == origin.port &&
      target.userInfo.isEmpty;

  static bool safeTransport(Uri uri) {
    if (uri.userInfo.isNotEmpty || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    if (uri.scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '::1') return true;
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((n) => n == null || n < 0 || n > 255)) {
      return false;
    }
    return parts[0] == 127 ||
        parts[0] == 10 ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31);
  }

  static void requireSafeTransport(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !safeTransport(uri)) {
      throw StateError('敏感连接必须使用 HTTPS；本机或局域网 IP 可使用 HTTP');
    }
  }

  static void requireOrigin(RequestOptions options, String baseUrl) {
    final origin = Uri.tryParse(baseUrl);
    if (origin == null ||
        !sameOrigin(options.uri, origin) ||
        !safeTransport(options.uri)) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: '已阻止向站点以外的地址或不安全连接发送凭据',
      );
    }
    // Automatic redirects can forward nonstandard keys such as x-api-key.
    options.followRedirects = false;
  }

  static void guard(Dio dio, String baseUrl) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          try {
            requireOrigin(options, baseUrl);
            handler.next(options);
          } on DioException catch (error) {
            handler.reject(error);
          }
        },
      ),
    );
  }
}
