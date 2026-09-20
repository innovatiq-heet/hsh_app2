import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../constants/app_config.dart';
import '../../../storage/session_store.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../request/fees/submit_payment_request.dart';
import '../../responses/fees/fee_responses.dart';

class FeesRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  Future<Options> _authOptions([Options? base]) async {
    final token = SessionStore.instance.currentToken ??
        await SessionStore.instance.token;
    final headers = Map<String, dynamic>.from(base?.headers ?? {});
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return (base ?? Options()).copyWith(headers: headers);
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['message'] is String &&
          (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
      if (data['error'] is String && (data['error'] as String).isNotEmpty) {
        return data['error'] as String;
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not connect to host at ${AppConfig.baseUrl}. Please verify Wi-Fi and server status.';
    }
    return e.message ?? 'Fee request failed. Please try again.';
  }

  /// Bootstrap aadhar resolver — `GET /fees/summary` also happens to be the
  /// endpoint the JWT's student aadhar comes back on,
  /// so this doubles as the primary source for [AadharResolvingMixin].
  /// Returns `null` on failure rather than throwing.
  Future<String?> resolveAadhar() async {
    try {
      final response = await _dio.get(
        '/fees/summary',
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final summary = payload['summary'];
          if (summary is Map<String, dynamic>) {
            final aadhar = summary['aadhar']?.toString();
            if (aadhar != null && aadhar.isNotEmpty) {
              return aadhar;
            }
          }
        }
      }
      return null;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get student financial summary, net due, and balances
  /// `GET /api/fees/summary`
  Future<FeeSummaryResponse> summary() async {
    try {
      final response = await _dio.get(
        '/fees/summary',
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final summaryData = payload['summary'];
          if (summaryData is Map<String, dynamic>) {
            return FeeSummaryResponse.fromJson(summaryData);
          }
        }
      }
      throw const ApiException('Invalid fee summary format received from server.');
    } on DioException catch (e) {
      developer.log('FeesRepository.summary error: ${e.response?.data}', name: 'FEES');
      throw ApiException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// List fee debits/invoices charged to student
  /// `GET /api/fees/debits`
  Future<List<FeeDebitResponse>> debits({
    dynamic year,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (year != null) {
        queryParams['year'] = year;
      }

      final response = await _dio.get(
        '/fees/debits',
        queryParameters: queryParams,
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final list = payload['debits'];
          if (list is List) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((e) => FeeDebitResponse.fromJson(e))
                .toList();
          }
        }
      }
      return [];
    } on DioException catch (e) {
      developer.log('FeesRepository.debits error: ${e.response?.data}', name: 'FEES');
      throw ApiException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// List security/caution deposits ledger
  /// `GET /api/fees/deposits`
  Future<List<DepositEntryResponse>> deposits({
    dynamic year,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (year != null) {
        queryParams['year'] = year;
      }

      final response = await _dio.get(
        '/fees/deposits',
        queryParameters: queryParams,
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final list = payload['deposits'];
          if (list is List) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((e) => DepositEntryResponse.fromJson(e))
                .toList();
          }
        }
      }
      return [];
    } on DioException catch (e) {
      developer.log('FeesRepository.deposits error: ${e.response?.data}', name: 'FEES');
      throw ApiException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// List payment transactions submitted by student
  /// `GET /api/fees/transactions`
  Future<List<FeeTransactionResponse>> transactions({
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final response = await _dio.get(
        '/fees/transactions',
        queryParameters: queryParams,
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final list = payload['transactions'];
          if (list is List) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((e) => FeeTransactionResponse.fromJson(e))
                .toList();
          }
        }
      }
      return [];
    } on DioException catch (e) {
      developer.log('FeesRepository.transactions error: ${e.response?.data}', name: 'FEES');
      throw ApiException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Submit a payment transaction slip for verification
  /// `POST /api/fees/transactions`
  Future<FeeTransactionResponse> submitPayment(
    SubmitPaymentRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/fees/transactions',
        data: request.toJson(),
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final txn = payload['transaction'];
          if (txn is Map<String, dynamic>) {
            return FeeTransactionResponse.fromJson(txn);
          }
        }
      }
      throw const ApiException('Invalid transaction confirmation received from server.');
    } on DioException catch (e) {
      developer.log('FeesRepository.submitPayment error: ${e.response?.data}', name: 'FEES');
      throw ApiException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }
}
