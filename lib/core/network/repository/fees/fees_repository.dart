import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';
import '../../request/fees/submit_payment_request.dart';
import '../../responses/fees/fee_responses.dart';

class FeesRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  /// Resolves the student's Aadhar from the fee-summary endpoint.
  ///
  /// Returns `null` on failure rather than throwing — used as the primary
  /// source by [AadharService]'s cascading fallback chain.
  Future<String?> resolveAadhar() async {
    try {
      final response = await _dio.get('/fees/summary');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final summary = payload['summary'];
          if (summary is Map<String, dynamic>) {
            final aadhar = summary['aadhar']?.toString();
            if (aadhar != null && aadhar.isNotEmpty) return aadhar;
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

  /// `GET /api/fees/summary` — student financial summary, net due, and balances.
  Future<FeeSummaryResponse> summary() async {
    try {
      final response = await _dio.get('/fees/summary');
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
      developer.log('summary error: ${e.response?.data}', name: 'FeesRepository');
      throw ApiException(errorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  /// `GET /api/fees/debits` — fee debits/invoices charged to student.
  Future<List<FeeDebitResponse>> debits({
    dynamic year,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit, 'offset': offset};
      if (year != null) params['year'] = year;
      final response = await _dio.get('/fees/debits', queryParameters: params);
      return _parseList<FeeDebitResponse>(
        response.data,
        'debits',
        FeeDebitResponse.fromJson,
      );
    } on DioException catch (e) {
      developer.log('debits error: ${e.response?.data}', name: 'FeesRepository');
      throw ApiException(errorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  /// `GET /api/fees/deposits` — security/caution deposits ledger.
  Future<List<DepositEntryResponse>> deposits({
    dynamic year,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit, 'offset': offset};
      if (year != null) params['year'] = year;
      final response =
          await _dio.get('/fees/deposits', queryParameters: params);
      return _parseList<DepositEntryResponse>(
        response.data,
        'deposits',
        DepositEntryResponse.fromJson,
      );
    } on DioException catch (e) {
      developer.log('deposits error: ${e.response?.data}', name: 'FeesRepository');
      throw ApiException(errorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  /// `GET /api/fees/transactions` — payment transactions submitted by student.
  Future<List<FeeTransactionResponse>> transactions({
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit, 'offset': offset};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final response =
          await _dio.get('/fees/transactions', queryParameters: params);
      return _parseList<FeeTransactionResponse>(
        response.data,
        'transactions',
        FeeTransactionResponse.fromJson,
      );
    } on DioException catch (e) {
      developer.log('transactions error: ${e.response?.data}', name: 'FeesRepository');
      throw ApiException(errorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  /// `POST /api/fees/transactions` — submit a payment slip for verification.
  Future<FeeTransactionResponse> submitPayment(SubmitPaymentRequest request) async {
    try {
      final response =
          await _dio.post('/fees/transactions', data: request.toJson());
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
      throw const ApiException(
          'Invalid transaction confirmation received from server.');
    } on DioException catch (e) {
      developer.log('submitPayment error: ${e.response?.data}', name: 'FeesRepository');
      throw ApiException(errorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  // ---------- Private helpers ----------

  List<T> _parseList<T>(
    dynamic body,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (body is! Map) return const [];
    final payload = body['data'];
    final list = payload is Map ? payload[key] : null;
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }
}
