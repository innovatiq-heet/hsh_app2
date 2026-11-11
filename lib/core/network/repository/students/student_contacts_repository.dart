import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';
import '../../../models/students/student_contacts_model.dart';

/// Repository for student contact management:
/// Base phone numbers (primary mobile, WhatsApp, father phone, mother phone)
/// and additional international/secondary contact numbers.
class StudentContactsRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Bulk list of all additional phone numbers across all students.
  /// Used by the PhonebookSyncService to overlay secondary and international contacts.
  Future<List<StudentAdditionalPhone>> getAllAdditionalContacts() =>
      _guard(() async {
        final response = await _dio.get('/students/all-contacts');
        final body = response.data;
        final data = body is Map ? body['data'] : body;
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) =>
                  StudentAdditionalPhone.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        return const [];
      });

  /// Fetches base contacts and additional phones for a specific student.
  Future<StudentContactsData> getContacts(String studentIdentifier) =>
      _guard(() async {
        final response =
            await _dio.get('/students/$studentIdentifier/contacts');
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        if (data is! Map) {
          throw const ApiException('Student contacts not found');
        }
        return StudentContactsData.fromJson(Map<String, dynamic>.from(data));
      });

  /// Adds a new additional / international phone number for a student.
  Future<StudentAdditionalPhone> addAdditionalPhone({
    required String studentIdentifier,
    required String phone,
    required String label,
    bool isWhatsApp = false,
    bool isPrimary = false,
  }) =>
      _guard(() async {
        final response = await _dio.post(
          '/students/$studentIdentifier/contacts',
          data: {
            'phone': phone.trim(),
            'label': label.trim(),
            'is_whatsapp': isWhatsApp,
            'is_primary': isPrimary,
          },
        );
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        if (data is! Map) {
          throw const ApiException('Failed to add phone number');
        }
        return StudentAdditionalPhone.fromJson(
            Map<String, dynamic>.from(data));
      });

  /// Updates an existing additional contact number.
  Future<StudentAdditionalPhone> updateAdditionalPhone({
    required String studentIdentifier,
    required int contactId,
    required String phone,
    required String label,
    bool isWhatsApp = false,
    bool isPrimary = false,
  }) =>
      _guard(() async {
        final response = await _dio.put(
          '/students/$studentIdentifier/contacts/$contactId',
          data: {
            'phone': phone.trim(),
            'label': label.trim(),
            'is_whatsapp': isWhatsApp,
            'is_primary': isPrimary,
          },
        );
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        if (data is! Map) {
          throw const ApiException('Failed to update phone number');
        }
        return StudentAdditionalPhone.fromJson(
            Map<String, dynamic>.from(data));
      });

  /// Deletes an additional phone number.
  Future<void> deleteAdditionalPhone({
    required String studentIdentifier,
    required int contactId,
  }) =>
      _guard(() async {
        await _dio.delete('/students/$studentIdentifier/contacts/$contactId');
      });

  /// Updates the base student contact details:
  /// Primary mobile number, WhatsApp number, Father phone, or Mother phone.
  Future<Map<String, dynamic>> updateBaseContactDetails({
    required String studentIdentifier,
    String? primaryPhone,
    String? whatsappNumber,
    String? fatherPhone,
    String? motherPhone,
  }) =>
      _guard(() async {
        final body = <String, dynamic>{};
        if (primaryPhone != null) body['phone_number'] = primaryPhone.trim();
        if (whatsappNumber != null) {
          body['whatsapp_number'] = whatsappNumber.trim();
        }
        if (fatherPhone != null) body['father_phone'] = fatherPhone.trim();
        if (motherPhone != null) body['mother_phone'] = motherPhone.trim();

        final response = await _dio.put(
          '/students/$studentIdentifier/contact-details',
          data: body,
        );
        final resData = response.data;
        return (resData is Map && resData['data'] is Map)
            ? Map<String, dynamic>.from(resData['data'])
            : <String, dynamic>{};
      });
}
