import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../../models/whatsapp/whatsapp_account.dart';
import '../../api_client.dart';
import '../base_repository.dart';

/// The WhatsApp numbers the server keeps connected (`/whatsapp/accounts`) and
/// the per-number connect / pair / disconnect calls. Every call without an
/// account id acts on the Main number, like before multi-number support.
class WhatsAppAccountsRepository extends BaseRepository {
  ApiClient get _apiClient => Get.find<ApiClient>();

  Future<T> _run<T>(Future<T> Function() call, String fallback) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw Exception(errorMessage(e, fallback: fallback));
    }
  }

  Map<String, dynamic> _data(Response response) {
    final body = response.data;
    if (body is Map && body['data'] is Map) return Map<String, dynamic>.from(body['data']);
    return const {};
  }

  Future<WhatsAppAccountsData> fetch() => _run(() async {
    final response = await _apiClient.dio.get('/whatsapp/accounts');
    return WhatsAppAccountsData.fromJson(_data(response));
  }, 'Could not load WhatsApp numbers.');

  /// Adds an empty slot; link it afterwards with [connect] or [pair].
  Future<String> add(String label) => _run(() async {
    final response = await _apiClient.dio.post('/whatsapp/accounts', data: {'label': label.trim()});
    final id = _data(response)['id']?.toString();
    if (id == null || id.isEmpty) throw Exception('The server did not return the new number.');
    return id;
  }, 'Could not add the number.');

  Future<void> rename(String id, String label) => _run(() async {
    await _apiClient.dio.put('/whatsapp/accounts/$id', data: {'label': label.trim()});
  }, 'Could not rename the number.');

  /// Logs the number out and removes it.
  Future<void> delete(String id) => _run(() async {
    await _apiClient.dio.delete('/whatsapp/accounts/$id');
  }, 'Could not remove the number.');

  /// Which number the scheduled daily run sends from. Only the keys given are
  /// sent; a `null` value means "use the Main number".
  Future<void> setDefaults(Map<String, String?> defaults) => _run(() async {
    await _apiClient.dio.put('/whatsapp/accounts/defaults', data: defaults);
  }, 'Could not save the default numbers.');

  Future<WhatsAppAccount> status(String id) => _run(() async {
    final response = await _apiClient.dio.get('/whatsapp/status', queryParameters: {'accountId': id});
    return WhatsAppAccount.fromJson({'id': id, ..._data(response)});
  }, 'Could not check the number.');

  /// Starts linking by QR; the QR arrives through [fetch] / [status].
  Future<void> connect(String id) => _run(() async {
    await _apiClient.dio.post('/whatsapp/connect', data: {'accountId': id});
  }, 'Could not start connecting.');

  /// 8-character pairing code. [phone] is digits with country code.
  Future<String> pair(String id, String phone) => _run(() async {
    final response = await _apiClient.dio.post(
      '/whatsapp/pair',
      data: {'phone': phone.trim(), 'accountId': id},
    );
    final body = response.data;
    if (body is Map && body['code'] != null) return body['code'].toString();
    throw Exception((body is Map ? body['message'] : null) ?? 'Failed to get a pairing code.');
  }, 'Could not get a pairing code. Please try again.');

  Future<void> disconnect(String id) => _run(() async {
    await _apiClient.dio.post('/whatsapp/disconnect', data: {'accountId': id});
  }, 'Could not disconnect the number.');
}
