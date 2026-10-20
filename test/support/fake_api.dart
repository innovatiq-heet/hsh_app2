import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hsh_app2/core/network/api_client.dart';

/// A reply from [FakeApi]: an HTTP status and a JSON body.
class FakeReply {
  final int status;
  final Object? body;

  const FakeReply(this.status, this.body);
}

/// Offline backend for repository and controller tests.
///
/// It replaces Dio's HTTP adapter, so the app's real interceptors and Dio's
/// status handling (4xx/5xx become a `DioException`) still run. Every request
/// is recorded; `options.data` keeps the JSON map or `FormData` sent.
class FakeApi implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  /// Replies keyed by "METHOD /path", e.g. "GET /complaint-categories".
  final routes = <String, FakeReply Function(RequestOptions)>{};

  void on(String route, Object? body, {int status = 200}) =>
      routes[route] = (_) => FakeReply(status, body);

  Iterable<RequestOptions> called(String route) =>
      requests.where((r) => '${r.method} ${r.path}' == route);

  RequestOptions last(String route) => called(route).last;

  /// Registers an [ApiClient] backed by this fake with GetX.
  ApiClient install() {
    final api = ApiClient.create();
    api.dio.httpClientAdapter = this;
    Get.put(api);
    return api;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Consume the body like a real adapter, so multipart uploads close the
    // files they read.
    await requestStream?.drain<void>();
    final reply = routes['${options.method} ${options.path}']?.call(options) ??
        const FakeReply(404, {'success': false, 'message': 'Not found'});
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Waits for [condition]; controllers start loading in `onInit` without
/// handing back the future.
Future<void> until(bool Function() condition, {String reason = ''}) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for: $reason');
}
