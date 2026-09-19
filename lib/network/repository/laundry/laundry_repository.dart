import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../common_enums/laundry_status.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../request/laundry/submit_laundry_request.dart';
import '../../responses/laundry/laundry_responses.dart';

class LaundryRepository {
  Dio get _dio {
    return Get.find<ApiClient>().dio;
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ??
        'Server communication error. Please check your network connection.';
  }

  // --- 4.1 Submit Laundry Ticket (POST /laundry) ---
  Future<LaundryTicketModel> submit(SubmitLaundryTicketRequest request) async {
    try {
      final response = await _dio.post('/laundry', data: request.toJson());
      final body = response.data;
      Map<String, dynamic> ticketData;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          ticketData = (data['laundry'] as Map<String, dynamic>?) ?? data;
        } else {
          ticketData = (body['laundry'] as Map<String, dynamic>?) ?? body;
        }
      } else {
        throw ApiException('Unexpected server response format');
      }
      return LaundryTicketModel.fromJson(ticketData);
    } on DioException catch (e) {
      developer.log('POST /laundry error: ${e.message}', name: 'LaundryRepository');
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log('POST /laundry parsing error: $e', name: 'LaundryRepository');
      throw ApiException('Failed to parse ticket data: $e');
    }
  }

  // --- 4.2 List Own Tickets (GET /laundry) ---
  Future<List<LaundryTicketModel>> tickets({LaundryStatus? status}) async {
    try {
      final query = <String, dynamic>{};
      if (status != null) query['status'] = status.apiValue;
      final response = await _dio.get('/laundry', queryParameters: query);
      return _extractTicketList(response.data);
    } on DioException catch (e) {
      developer.log('GET /laundry error: ${e.message}', name: 'LaundryRepository');
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log('GET /laundry parsing error: $e', name: 'LaundryRepository');
      throw ApiException('Failed to load tickets: $e');
    }
  }

  // --- 4.3 Get Ticket Details (GET /laundry/:id) ---
  Future<LaundryTicketModel> ticketDetail(dynamic id) async {
    try {
      final response = await _dio.get('/laundry/$id');
      final body = response.data;
      Map<String, dynamic> ticketData;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          ticketData = (data['laundry'] as Map<String, dynamic>?) ?? data;
        } else {
          ticketData = (body['laundry'] as Map<String, dynamic>?) ?? body;
        }
      } else {
        throw ApiException('Unexpected server response format');
      }
      return LaundryTicketModel.fromJson(ticketData);
    } on DioException catch (e) {
      developer.log('GET /laundry/$id error: ${e.message}', name: 'LaundryRepository');
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log('GET /laundry/$id parsing error: $e', name: 'LaundryRepository');
      throw ApiException('Failed to load ticket details: $e');
    }
  }

  // --- 4.4 Get Laundry Balance (GET /laundry/balance) ---
  Future<LaundryBalanceModel> balance({String? aadhar}) async {
    try {
      final query = <String, dynamic>{};
      if (aadhar != null && aadhar.isNotEmpty) query['aadhar'] = aadhar;
      final response =
          await _dio.get('/laundry/balance', queryParameters: query);
      final body = response.data;
      Map<String, dynamic> balData;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          balData = (data['balance'] as Map<String, dynamic>?) ?? data;
        } else {
          balData = (body['balance'] as Map<String, dynamic>?) ?? body;
        }
      } else {
        throw ApiException('Unexpected server response format');
      }
      return LaundryBalanceModel.fromJson(balData);
    } on DioException catch (e) {
      developer.log('GET /laundry/balance error: ${e.message}', name: 'LaundryRepository');
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log('GET /laundry/balance parsing error: $e', name: 'LaundryRepository');
      throw ApiException('Failed to load laundry balance: $e');
    }
  }

  // --- 4.5 List ALL Tickets (Admin/Staff View: GET /laundry/admin) ---
  Future<List<LaundryTicketModel>> adminTickets({
    LaundryStatus? status,
    String? aadhar,
    String? room,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (status != null) query['status'] = status.apiValue;
      if (aadhar != null && aadhar.isNotEmpty) query['aadhar'] = aadhar;
      if (room != null && room.isNotEmpty) query['room'] = room;
      final response = await _dio.get('/laundry/admin', queryParameters: query);
      return _extractTicketList(response.data);
    } on DioException catch (e) {
      developer.log('GET /laundry/admin error: ${e.message}', name: 'LaundryRepository');
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log('GET /laundry/admin parsing error: $e', name: 'LaundryRepository');
      throw ApiException('Failed to load laundry orders: $e');
    }
  }

  // --- 4.6 Update Ticket (PATCH /laundry/admin/:id) ---
  Future<LaundryTicketModel> updateTicket(
    dynamic id,
    UpdateLaundryTicketRequest request,
  ) async {
    try {
      final response = await _dio.patch(
        '/laundry/admin/$id',
        data: request.toJson(),
      );
      final body = response.data;
      Map<String, dynamic> ticketData;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          ticketData = (data['laundry'] as Map<String, dynamic>?) ?? data;
        } else {
          ticketData = (body['laundry'] as Map<String, dynamic>?) ?? body;
        }
      } else {
        throw ApiException('Unexpected server response format');
      }
      return LaundryTicketModel.fromJson(ticketData);
    } on DioException catch (e) {
      developer.log(
        'PATCH /laundry/admin/$id error: ${e.message}',
        name: 'LaundryRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log(
        'PATCH /laundry/admin/$id parsing error: $e',
        name: 'LaundryRepository',
      );
      throw ApiException('Failed to update ticket: $e');
    }
  }

  // --- 4.7 Delete Ticket (Admin ONLY: DELETE /laundry/admin/:id) ---
  Future<void> deleteTicket(dynamic id) async {
    try {
      await _dio.delete('/laundry/admin/$id');
    } on DioException catch (e) {
      developer.log(
        'DELETE /laundry/admin/$id error: ${e.message}',
        name: 'LaundryRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  // --- 4.8 Recharge Student Balance (POST /laundry/admin/recharge) ---
  Future<LaundryRechargeModel> recharge(String aadhar, double amount) async {
    try {
      final response = await _dio.post(
        '/laundry/admin/recharge',
        data: {'aadhar': aadhar, 'amount': amount},
      );
      final body = response.data;
      Map<String, dynamic> rechargeData;
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          rechargeData = (data['recharge'] as Map<String, dynamic>?) ?? data;
        } else {
          rechargeData = (body['recharge'] as Map<String, dynamic>?) ?? body;
        }
      } else {
        throw ApiException('Unexpected server response format');
      }
      return LaundryRechargeModel.fromJson(rechargeData);
    } on DioException catch (e) {
      developer.log(
        'POST /laundry/admin/recharge error: ${e.message}',
        name: 'LaundryRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log(
        'POST /laundry/admin/recharge parsing error: $e',
        name: 'LaundryRepository',
      );
      throw ApiException('Failed to process recharge: $e');
    }
  }

  // --- 4.9 View Recharge History (GET /laundry/admin/recharges/:aadhar) ---
  Future<List<LaundryRechargeModel>> rechargeHistory(String aadhar) async {
    try {
      final response = await _dio.get('/laundry/admin/recharges/$aadhar');
      final body = response.data;
      dynamic rawList;
      if (body is List) {
        rawList = body;
      } else if (body is Map) {
        final data = body['data'];
        if (data is List) {
          rawList = data;
        } else if (data is Map) {
          rawList = data['recharges'] ??
              data['history'] ??
              data['items'] ??
              data['transactions'];
        } else {
          rawList = body['recharges'] ?? body['history'];
        }
      }
      if (rawList is List) {
        return rawList
            .map((e) =>
                LaundryRechargeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      developer.log(
        'GET /laundry/admin/recharges error: ${e.message}',
        name: 'LaundryRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log(
        'GET /laundry/admin/recharges parsing error: $e',
        name: 'LaundryRepository',
      );
      throw ApiException('Failed to load recharge history: $e');
    }
  }

  Future<List<LaundryRechargeModel>> recharges(String aadhar) =>
      rechargeHistory(aadhar);

  Future<LaundryTicketModel> advanceStatus(dynamic ticketId) async {
    final ticket = await ticketDetail(ticketId);
    final nextIndex = (ticket.status.stageIndex + 1).clamp(
      0,
      LaundryStatus.values.length - 1,
    );
    final next = LaundryStatus.values[nextIndex];
    return updateTicket(
      ticketId,
      UpdateLaundryTicketRequest(status: next),
    );
  }

  List<LaundryTicketModel> _extractTicketList(dynamic body) {
    dynamic rawList;
    if (body is List) {
      rawList = body;
    } else if (body is Map) {
      final data = body['data'];
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList = data['laundry'] ??
            data['tickets'] ??
            data['orders'] ??
            data['items'] ??
            data['results'];
      } else {
        rawList = body['laundry'] ?? body['tickets'] ?? body['results'];
      }
    }
    if (rawList is List) {
      return rawList
          .map((e) =>
              LaundryTicketModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
